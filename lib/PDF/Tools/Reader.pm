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

    multi method open( Str $input, *%opts) {
        $.open( $input.IO.open( :enc<latin-1> ), |%opts );
    }

    multi method open( $input!, Bool :$rebuild-index? ) {
        use PDF::Tools::Input;

        $!input = $input.isa(PDF::Tools::Input)
                  ?? $input
                  !! PDF::Tools::Input.new-delegate( :value($input) );

        my $actions = PDF::Grammar::PDF::Actions.new;

        $.load-header( :$actions );
        $.load-xref( :$actions );

    }

    method ind-obj( Int $obj-num!, Int $gen-num! ) {

        my $ind-obj := %!ind-obj-idx{ $obj-num }{ $gen-num }<ind-obj>
            // die "unable to find object: $obj-num $gen-num R";

        unless $ind-obj.isa(PDF::Tools::IndObj) {
            # 'compile' the object
            my $encoded := %!ind-obj-idx{ $obj-num }{ $gen-num }<encoded>:delete;
            $ind-obj = PDF::Tools::IndObj.new-delegate( :$ind-obj, :$encoded );
        }

        $ind-obj;
    }

    #| construct an AST from a possibly raw (when :gentle) or stantiated object
    method ind-obj-ast( Int $obj-num!, Int $gen-num!, :$gentle=True ) {
        my $ind-obj := %!ind-obj-idx{ $obj-num }{ $gen-num }<ind-obj>
            // die "unable to find object: $obj-num $gen-num R";

        my $ast;

        if $ind-obj.isa(PDF::Tools::IndObj) {
            # already stantiated
            $ast = $ind-obj.ast;
        }
        elsif $gentle {
            # avoid object stantiation reconstruct from raw input data.
            my $encoded := %!ind-obj-idx{ $obj-num }{ $gen-num }<encoded>;
            if $encoded {
                # merge encoded data into ast
                my %value = :$encoded, %( $ind-obj[2].value );
                %value<start>:delete;
                $ast = :ind-obj[ $ind-obj[0], $ind-obj[1], $ind-obj[2].key => %value.item ];
            }
            else {
                $ast = :$ind-obj;
            }
        }
        else {
            $ast = $.ind-obj( $obj-num, $gen-num ).ast;
        }

        return $ast;
    }

    multi method deref(Pair $_! where .key eq 'ind-ref' ) {
        my $obj-num = .value[0].Int;
        my $gen-num = .value[1].Int;
        return $.ind-obj( $obj-num, $gen-num ).ast;
    }

    multi method deref($other) is default {
        $other;
    }

    method load-header(:$actions!) {
        # file should start with: %PDF-n.m, (where n, m are single
        # digits giving the major and minor version numbers).
            
        my $preamble = $.input.substr(0, 8);

        PDF::Grammar::PDF.parse($preamble, :$actions, :rule<header>)
            or die "expected file header '%PDF-n.m', got: {$preamble.perl}";

        $.version = $/.ast.value;
    }

    method load-xref(:$actions) {

        # todo: utilize Perl 6 cat strings, when available 
        # locate and read the file trailer
        # hmm, arbritary magic number
        my $tail-bytes = min(1024, $.input.chars);
        my $tail = $.input.substr(* - $tail-bytes);

        my %offsets-seen;

        PDF::Grammar::PDF.parse($tail, :$actions, :rule<postamble>)
            or die "expected file trailer 'startxref ... \%\%EOF', got: {$tail.perl}";
        my $xref-offset = $/.ast.value;

        my $root-object-ref;
        my @type1-obj-refs;
        my %type2-obj-refs;

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
                PDF::Grammar::PDF.subparse( $xref, :rule<index>, :$actions )
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
                PDF::Grammar::PDF.subparse($xref, :$actions, :rule<ind-obj>)
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
                                my $type1-obj-num = $idx[1];
                                my $index = $idx[2];
                                %type2-obj-refs{ $type1-obj-num }.push: $index;
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

        my @deferred-objs;

        # 1. index top-level indirect objects, other than streams
        for @type1-obj-refs.kv -> $k, $v {
            my $offset = $v<offset>;
            my $next-offset = $k + 1 < +@type1-obj-refs ?? @type1-obj-refs[$k + 1]<offset> !! $.input.chars;
            my $length-pessimistic = $next-offset - $offset - 1;
            my $length = min( $length-pessimistic, 1024 );
            my $chunk = $.input.substr( $offset, $length );

            my $p = PDF::Grammar::PDF.subparse( $chunk, :$actions, :rule<ind-obj-nibble> );
            if ! $p && $length < $length-pessimistic {
                $chunk ~= $.input.substr( $offset + $length, $length-pessimistic - $length );
                $p = PDF::Grammar::PDF.subparse( $chunk, :$actions, :rule<ind-obj-nibble> );
            }

            die "unable to parse indirect object \@$offset +$length"
                unless $p;
            my $ind-obj = $p.ast.value;
            my ($obj-num, $gen-num, $obj) = @$ind-obj;

            warn "index entry was: $v<obj-num> $v<gen-num> R. actual object: $obj-num $gen-num R"
                unless $obj-num == $v<obj-num> && $gen-num == $v<gen-num>;

            if $obj.key eq 'stream' {
                # defer as stream length may be forward references, e.g.
                # 218 0 obj << /Filter /FlateDecode /Length 219 0 R >> stream
                @deferred-objs.push: [ $ind-obj, $offset ];
            }
            else {
                %!ind-obj-idx{ $obj-num }{ $gen-num } //= { :$ind-obj, :type(1), :$offset };
            }
        }

        for @deferred-objs {
            my ($ind-obj, $offset) = @$_;
            my ($obj-num, $gen-num, $obj-raw) = @$ind-obj;
            %!ind-obj-idx{ $obj-num }{ $gen-num } //= do {
                die "stream object without a length: obj $obj-num $gen-num ... \@$offset"
                    unless $obj-raw.value<dict><Length>.defined;

                my $start = $obj-raw.value<start>;
                my $length = unbox( $.deref( $obj-raw.value<dict><Length> ) );
                my $encoded = $.input.substr( $offset + $start, $length );
                %!ind-obj-idx{ $obj-num }{ $gen-num } //= { :$ind-obj, :$encoded, :type(1), :$offset };
            };
        }

        for %type2-obj-refs.keys.sort -> $type1-obj-num {
            my $indices = %type2-obj-refs{$type1-obj-num};
            my $type1-obj = $.ind-obj( $type1-obj-num.Int, 0);
            my $type2-objects = $type1-obj.decoded;

            for $indices.list -> $item {
                my $ind-obj = $type2-objects[ $item ];
                my $obj-num = $ind-obj[0];
                my $gen-num = $ind-obj[1];
                %!ind-obj-idx{ $obj-num }{ $gen-num } //= { :$ind-obj, :type(2), :parent($type1-obj-num), :$item };
            }
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
                my $ind-obj-ast = $.ind-obj-ast($obj-num, $gen-num, :gentle);
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
                        my $parent = $entry<parent>;
                        $offset = %!ind-obj-idx{ $parent }{0}<offset>;
                        $seq = $entry<item>;
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
