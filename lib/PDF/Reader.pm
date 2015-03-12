use v6;

class PDF::Reader {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::Tools::IndObj;

    has $.input is rw;  # raw PDF image (latin-1 encoding)
    has Hash %!ind-obj-idx;
    has $.root is rw;
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

    multi method open( $input!) {
        use PDF::Tools::Input;

        $!input = PDF::Tools::Input.compose( :value($input) );

        $.load-header( );
        $.load-xref( );
    }

    method ind-obj( Int $obj-num!, Int $gen-num!, :$type, :$get-ast=False ) {

        my $idx := %!ind-obj-idx{ $obj-num }{ $gen-num }
            // die "unable to find object: $obj-num $gen-num R";

        my $ind-obj = $idx<ind-obj> //= do {
            # stantiate the object
            my $ind-obj;
            my $actual-obj-num;
            my $actual-gen-num;
 
            given $idx<type> {
                when 1 {
                    # type 1 reference to an external object
                    my $offset = $idx<offset>;
                    my $end = $idx<end>;
                    my $max-length = $end - $offset - 1;
                    my $input = $.input.substr( $offset, $max-length );
                    PDF::Grammar::PDF.subparse( $input, :$.actions, :rule<ind-obj-nibble> )
                        // die "unable to parse indirect object: $obj-num $gen-num R \@$offset";

                    $ind-obj = $/.ast.value;
                    ($actual-obj-num, $actual-gen-num, my $obj-raw) = @$ind-obj;

                    if $obj-raw.key eq 'stream' {

                        $obj-raw.value<encoded> //= do {
                            die "stream mandatory /Length field is missing: $obj-num $gen-num R \@$offset"
                                unless $obj-raw.value<dict><Length>;

                            my $length = $.deref( $obj-raw.value<dict><Length> ).value;
                            my $start = $obj-raw.value<start>:delete;
                            die "stream Length $length appears too large (> $max-length): $obj-num $gen-num R \@$offset"
                                if $start + $length > $max-length;

                            # ensure stream is followed by an 'endstream' marker
                            if $input.substr( $start + $length ) ~~ m{^ (.*?) <PDF::Grammar::PDF::stream-tail>} {
                                if $0.chars {
                                    # hmm some unprocessed bytes
                                    warn "ignoring {$0.chars} bytes before 'endstream' marker: $obj-num $gen-num R \@$offset"
                                }
                            }
                            else {
                                die "die unable to locate 'endstream' marker after consuming /Length $length bytes: $obj-num $gen-num R \@$offset"
                            }
                            $input.substr( $start, $length );
                        };
                    }
                }
                when 2 {
                    # type 2 embedded object
                    my $container-obj = $.ind-obj( $idx<ref-obj-num>, 0, :type<ObjStm> ).object;
                    my $type2-objects = $container-obj.decoded;

                    my $index = $idx<index>;
                    my $ind-obj-ref = $type2-objects[ $index ];
                    $actual-obj-num = $ind-obj-ref[0];
                    $actual-gen-num = 0;
                    my $input = $ind-obj-ref[1];

                    PDF::Grammar::PDF.subparse( $input, :$.actions, :rule<object> )
                        // die "unable to parse indirect object: $obj-num $gen-num R\n$input";
                    $ind-obj = [ $actual-obj-num, $actual-gen-num, $/.ast ];
                }
                default {die "unhandled index type: $_"};
            };

            die "index entry was: $obj-num $gen-num R. actual object: $actual-obj-num $actual-gen-num R"
                unless $obj-num == $actual-obj-num && $gen-num == $actual-gen-num;

            # only full stantiate object when needed
            $get-ast ?? $ind-obj !! PDF::Tools::IndObj.new( :$ind-obj :$type );
        };

        if $ind-obj.isa(PDF::Tools::IndObj) {
            # regenerate ast from object, which may be updated between fetches
            return $get-ast ?? $ind-obj.ast !! $ind-obj;
        }
        elsif $get-ast {
            # user wants a raw object, that's what we've got
            return (:$ind-obj);
        }
        else {
            # need to create an object from the ast. save the object in the index
            return $idx<ind-obj> = PDF::Tools::IndObj.new( :$ind-obj :$type );
        }
    }

    multi method deref(Pair $_! where .key eq 'ind-ref' ) {
        my $obj-num = .value[0].Int;
        my $gen-num = .value[1].Int;
        return $.ind-obj( $obj-num, $gen-num, :get-ast );
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

        my $root-ref;
        my @obj-idx;

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
                        my $gen-num = .<gen-num>;
                        my $offset = .<offset>;

                        given $type {
                            when 0  {} # ignore free objects
                            when 1  { @obj-idx.push: { :$type, :$obj-num, :$gen-num, :$offset } }
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
                my $ind-obj = PDF::Tools::IndObj.new( |%ast, :input($xref), :type<XRef> );
                my $xref-obj = $ind-obj.object;
                $dict = $xref-obj;
                @obj-idx.push: $xref-obj.decode-to-stage2.list;
            }

            $root-ref //= $dict<Root>
                if $dict<Root>:exists;

            $xref-offset = $dict<Prev>:exists
                ?? $dict<Prev>
                !! Mu;
        }

        my %obj-entries-of-type = @obj-idx.classify({.<type>});

        my @type1-obj-entries = %obj-entries-of-type<1>.list.sort({ $^a<offset> })
            if %obj-entries-of-type<1>:exists;

        for @type1-obj-entries.kv -> $k, $v {
            my $obj-num = $v<obj-num>;
            my $gen-num = $v<gen-num>;
            my $offset = $v<offset>;
            my $end = $k + 1 < +@type1-obj-entries ?? @type1-obj-entries[$k + 1]<offset> !! $.input.chars;
            %!ind-obj-idx{ $obj-num }{ $gen-num } = { :type(1), :$offset, :$end };
        }

        my @type2-obj-entries = %obj-entries-of-type<2>.list
        if %obj-entries-of-type<2>:exists;

        for @type2-obj-entries {
            my $obj-num = .<obj-num>;
            my $index = .<index>;
            my $ref-obj-num = .<ref-obj-num>;

            %!ind-obj-idx{ $obj-num }{ 0 } = { :type(2), :$index, :$ref-obj-num };
        }

        $root-ref.defined
            ?? $!root = $.ind-obj( $root-ref.value[0], $root-ref.value[1] )
            !! die "unable to find root object";
    }

    #| - sift /XRef objects
    #| - delinearize
    #| - preserve input order
    #| :unpack 1.4- compatible asts:
    #| -- sift /ObjStm objects,
    #| -- keep type 2 objects
    #| :!unpack 1.5+ (/ObjStm aware) compatible asts:
    #| -- sift type 2 objects
    method !get-objects(Bool :$unpack!) {
        my @object-refs;

        my %objstm-objects;
        for %!ind-obj-idx.values>>.values {
            # implicitly an objstm object, if it contains type2 (compressed) objects
            %objstm-objects{ .<ref-obj-num> }++
                if .<type> == 2;
        }

        for %!ind-obj-idx.pairs {
            my $obj-num = .key.Int;

            # discard objstm objects (/Type /ObjStm)
            next
                if $unpack && %objstm-objects{$obj-num};

            for .value.pairs {
                my $gen-num = .key.Int;
                my $entry = .value;
                my $seq = 0;
                my $offset;

                given $entry<type> {
                    when 0 {
                        # type 0 freed object
                        next;
                    }
                    when 1 {
                        # type 1 regular top-level/inuse object
                        $offset = $entry<offset>
                    } 
                    when 2 {
                        # type 2 embedded object
                        next unless $unpack;

                        my $parent = $entry<ref-obj-num>;
                        $offset = %!ind-obj-idx{ $parent }{0}<offset>;
                        $seq = $entry<index>;
                    }
                    default { die "unknown ind-obj index <type> $obj-num $gen-num: {.perl}" }
                }

                my $ind-obj-ast = $.ind-obj($obj-num, $gen-num, :get-ast);
                my $ind-obj = $ind-obj-ast.value[2];

                if my $obj-type = $ind-obj.value<dict><Type> {
                    # discard existing /Type /XRef objects. These are specific to the input PDF
                    next if $obj-type.value eq 'XRef'
                }

                @object-refs.push: [ $ind-obj-ast, $offset + $seq ];
            }
        }

        # preserve input order
        my @objects := @object-refs.sort({$^a[1]}).map: {.[0]};

        # Discard Linearization aka "Fast Web View"
        my $first-ind-obj = @objects[0].value[2];
        if $first-ind-obj.key eq 'dict' && $first-ind-obj.value<Linearized> {
            @objects.shift;
        }

        return @objects.item;
    }

    method ast( Bool :$unpack = True ) {
        my $objects = self!"get-objects"( :$unpack );

        :pdf{
            :header{ :$.version },
            :body{ :$objects },
        };
    }

}
