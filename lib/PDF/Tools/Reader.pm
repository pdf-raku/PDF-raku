use v6;

class PDF::Tools::Reader {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::Tools::IndObj;
    use PDF::Tools::Util :unbox;

    has $.input is rw;  # raw PDF image (latin-1 encoding)
    has Hash %!ind-obj-idx;
    has $.root-object is rw;
    has $.ast is rw;
    has Rat $.version is rw;
    has Bool $.debug is rw;
    has PDF::Grammar::PDF::Actions $!actions;

    method actions {
        $!actions //= PDF::Grammar::PDF::Actions.new
    }

    multi method open( Str $input, *%opts) {
        $.open( $input.IO.open( :enc<latin-1> ), |%opts );
    }

    multi method open( $input!, Bool :$rebuild-index? ) {
        use PDF::Tools::Input;

        $!input = $input.isa(PDF::Tools::Input)
                  ?? $input
                  !! PDF::Tools::Input.new-delegate( :value($input) );

        warn "loading xref...";
        $.load-header( );
        $.load-xref( );
        warn "...done";
    }

    method ind-obj( Int $obj-num!, Int $gen-num!, :$type ) {

        my $idx := %!ind-obj-idx{ $obj-num }{ $gen-num }
            // die "unable to find object: $obj-num $gen-num R";

        my $ind-obj = $idx<ind-obj> //= do {
            # stantiate the object
            my $ind-obj;
            my $encoded;
            my $actual-obj-num;
            my $actual-gen-num;
 
            given $idx<type> {
                when 1 {
                    # type 1 reference to an external object
                    my $offset = $idx<offset>;
                    my $end = $idx<end>;
                    my $length = $end - $offset - 1;
                    my $input = $.input.substr( $offset, $length );
                    PDF::Grammar::PDF.subparse( $input, :$.actions, :rule<ind-obj-nibble> )
                        // die "unable to parse indirect object: $obj-num $gen-num R \@$offset";

                    $ind-obj = $/.ast.value;
                    ($actual-obj-num, $actual-gen-num, my $obj-raw) = @$ind-obj;

                    if $obj-raw.key eq 'stream' {
                        my $length = unbox( $.deref( $obj-raw.value<dict><Length> ) );
                        my $start = $obj-raw.value<start>;
                        $encoded = $.input.substr( $offset + $start, $length );
                    }

                }
                when 2 {
                    # type 2 embedded object
                    my $container-obj = $.ind-obj( $idx<ref-obj-num>, 0, :type<ObjStm> );
                    my $type2-objects = $container-obj.decoded;

                    my $index = $idx<index>;
                    my $ind-obj-ref = $type2-objects[ $index ];
                    $actual-obj-num = $ind-obj-ref[0];
                    $actual-gen-num = $ind-obj-ref[1];
                    my $input = $ind-obj-ref[2];

                    PDF::Grammar::PDF.subparse( $input, :$.actions, :rule<object> )
                        // die "unable to parse indirect object: $obj-num $gen-num R\n$input";
                    $ind-obj = [ $actual-obj-num, $actual-gen-num, $/.ast ];
                }
                default {die "unhandle type in index: $_"};
            };

            die "index entry was: $obj-num $gen-num R. actual object: $actual-obj-num $actual-gen-num R"
                unless $obj-num == $actual-obj-num && $gen-num == $actual-gen-num;

            PDF::Tools::IndObj.new-delegate( :$ind-obj, :$encoded, :$type );
        };

        $ind-obj;
    }

    multi method deref(Pair $_! where .key eq 'ind-ref' ) {
        my $obj-num = .value[0].Int;
        my $gen-num = .value[1].Int;
        return $.ind-obj( $obj-num, $gen-num ).ast;
    }

    multi method deref($other) is default {
        $other;
    }

    method load-header() {
        # file should start with: %PDF-n.m, (where n, m are single
        # digits giving the major and minor version numbers).
            
        my $preamble = $.input.substr(0, 8);

        PDF::Grammar::PDF.parse($preamble, :$.actions, :rule<header>)
            or die "expected file header '%PDF-n.m', got: {$preamble.perl}";

        $.version = $/.ast.value;
    }

    method load-xref() {

        # todo: utilize Perl 6 cat strings, when available 
        # locate and read the file trailer
        # hmm, arbritary magic number
        my $tail-bytes = min(1024, $.input.chars);
        my $tail = $.input.substr(* - $tail-bytes);

        my %offsets-seen;

        PDF::Grammar::PDF.parse($tail, :$.actions, :rule<postamble>)
            or die "expected file trailer 'startxref ... \%\%EOF', got: {$tail.perl}";
        my $xref-offset = $/.ast.value;

        my $root-object-ref;
        my @type1-obj-refs;
        my @type2-obj-refs;

        while $xref-offset.defined {
            die "xref '/Prev' cycle detected \@$xref-offset"
                if %offsets-seen{0 + $xref-offset}++;
            # see if our cross reference table is already contained in the current tail
            my $xref;
            my $dict;
            my $tail-xref-pos = $xref-offset - $.input.chars + $tail-bytes;
            if $tail-xref-pos >= 0 {
                $xref = $tail.substr( $tail-xref-pos );
            }
            else {
                my $xref-len = min(2048, $.input.chars - $xref-offset);
                $xref = $.input.substr( $xref-offset, $xref-len );
            }

            if $xref ~~ /^'xref'/ {
                # PDF 1.4- xref table followed by trailer
                PDF::Grammar::PDF.subparse( $xref, :rule<index>, :$.actions )
                    or die "unable to parse index: $xref";
                my ($xref-ast, $trailer-ast) = @( $/.ast );
                $dict = $trailer-ast<trailer>.value;

                my $prev-offset;

                for $xref-ast<xref>.list {
                    my $obj-num = .<object-first-num>;
                    for @( .<entries> ) {
                        my $type = .<type>;
                        my $gen-num = .<gen>;
                        my $offset = .<offset>;

                        given $type {
                            when 0 {} # ignore free objects
                            when 1 { @type1-obj-refs.push: { :$obj-num, :$gen-num, :$offset } }
                            default { die "unhandled type: $_" }
                        }
                        $obj-num++;
                    }
                }
            }
            else {
                # PDF 1.5+ XRef Stream
                PDF::Grammar::PDF.subparse($xref, :$.actions, :rule<ind-obj>)
                    // die "ind-obj parse failed \@$xref-offset + {$xref.chars}";

                my %ast = %( $/.ast );
                my $xref-obj = PDF::Tools::IndObj.new-delegate( |%ast, :input($xref), :type<XRef> );
                my $ref = [ $xref-obj.obj-num, $xref-obj.gen-num ];

                $dict = $xref-obj.dict;
                my $size = unbox $xref-obj.Size;
                my $index = $xref-obj.Index
                    ?? unbox $xref-obj.Index
                    !! [0, $size];

                my $xref-array = $xref-obj.decoded;
                my $i = 0;

                for $index.list -> $obj-num is rw, $entries {
                    for 1..$entries {
                        my $idx = $xref-array[$i++];
                        my $type = $idx[0];
                        given $type {
                            when 0 {}; # ignore free object
                            when 1 {
                                my $offset = $idx[1];
                                my $gen-num = $idx[2];
                                @type1-obj-refs.push: { :$obj-num, :$gen-num, :$offset };
                            }
                            when 2 {
                                my $ref-obj-num = $idx[1];
                                my $index = $idx[2];
                                @type2-obj-refs.push: { :$obj-num, :gen-num(0), :$ref-obj-num, :$index };
                            }
                            default {
                                die "XRef index object type outside range 0..2: $type \@$xref-offset"
                            }
                        }
                        $obj-num++;
                    }
                }
            }

            $root-object-ref //= $dict<Root>
                if $dict<Root>:exists;

            $xref-offset = $dict<Prev>:exists
                ?? unbox( $dict<Prev> )
                !! Mu;
        }

        @type1-obj-refs = @type1-obj-refs.sort: { $^a<offset> };

        for @type1-obj-refs.kv -> $k, $v {
            my $obj-num = $v<obj-num>;
            my $gen-num = $v<gen-num>;
            my $offset = $v<offset>;
            my $end = $k + 1 < +@type1-obj-refs ?? @type1-obj-refs[$k + 1]<offset> !! $.input.chars;
            %!ind-obj-idx{ $obj-num }{ $gen-num } = { :type(1), :$offset, :$end };
        }

        for @type2-obj-refs {
            my $obj-num = .<obj-num>;
            my $gen-num = .<gen-num>;
            my $index = .<index>;
            my $ref-obj-num = .<ref-obj-num>;

            %!ind-obj-idx{ $obj-num }{ $gen-num } = { :type(2), :$index, :$ref-obj-num };
        }

        $root-object-ref.defined
            ?? $!root-object = $.ind-obj( $root-object-ref.value[0], $root-object-ref.value[1] )
            !! die "unable to find root object";
    }

    #| - sift /XRef objects
    #| - delinearize
    #| - preserve input order
    #| 1.5+ (/ObjStm aware) compatible asts:
    #| -- sift type 2 objects
    #| 1.4- compatible asts:
    #| -- sift /ObjStm objects,
    #| -- keep type 2 objects
    method sift-objects(Rat :$compat!) {
        my @objects;
        for %!ind-obj-idx.pairs {
            my $obj-num = .key.Int;
            for .value.pairs {
                my $gen-num = .key.Int;
                my $entry = .value;
                my $ind-obj-ast = $.ind-obj($obj-num, $gen-num).ast;
                my $ind-obj = $ind-obj-ast.value[2];
                my $seq = 0;
                my $offset;

                given $entry<type> {
                    when 1 {
                        if $ind-obj.key eq 'stream' {
                            if my $obj-type = $ind-obj.value<dict><Type> {
                                next if $obj-type.value eq 'XRef'
                                    || ($compat < 1.5 && $obj-type.value eq 'ObjStm');
                            }
                        }
                        $offset = $entry<offset>
                    } 
                    when 2 {
                        next if $compat >= 1.5;
                        my $parent = $entry<ref-obj-num>;
                        $offset = %!ind-obj-idx{ $parent }{0}<offset>;
                        $seq = $entry<index>;
                    }
                    default { die "unknown ind-obj index <type> $obj-num $gen-num: {.perl}" }
                }

                @objects.push: [ $ind-obj-ast, $offset, $seq ];
            }
        }

        @objects := @objects.sort({$^a[1] + $^a[2]}).map({.[0]});

        # Discard Linearization aka "Fast Web View"
        my $first-ind-obj = @objects[0].value[2];
        if $first-ind-obj.key eq 'dict' && $first-ind-obj.value<Linearized> {
            @objects.shift;
        }

        return @objects.item;
    }

    method ast( Rat :$compat=1.4 ) {
        my $objects = $.sift-objects( :$compat );

        :pdf{
            :header{ :$.version },
            :body{ :$objects },
        };
    }

}
