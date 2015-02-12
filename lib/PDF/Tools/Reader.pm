use v6;

class PDF::Tools::Reader {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::Tools::IndObj;
    use PDF::Tools::Util :unbox;

    has $.input is rw;  # raw PDF image (latin-1 encoding)
    has Hash %!ind-obj-idx;
    has $.root-obj is rw;
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
        return %!ind-obj-idx{ $obj-num }{ $gen-num }
        or die "unable to find object: $obj-num $gen-num R";
    }

    multi method deref(Pair $_! where .key eq 'ind-ref' ) {
        my $obj-num = .value[0].Int;
        my $gen-num = .value[1].Int;
        return %!ind-obj-idx{ $obj-num }{ $gen-num }
        // die "unresolved object reference: $obj-num $gen-num R";
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

        # just slurp the entire PDF into memory
        # to utilize Perl 6 cat strings, when available 
        # locate and read the file trailer
        # hmm, arbritary magic number
        my $tail-bytes = min(1024, $.input.chars);
        my $tail = $.input.substr(* - $tail-bytes);

        my %offsets-seen;

        PDF::Grammar::PDF.parse($tail, :$actions, :rule<postamble>)
            or die "expected file trailer 'startxref ... \%\%EOF', got: {$tail.perl}";
        my $xref-offset = $/.ast.value;

        my $root-obj-ref;
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
                    for @( .<entries> ) {
                        my $status = .<status>;
                        my $gen = .<gen>;
                        my $offset = .<offset>;
                        next if $status eq 'f'; # don't index free objects

                        @type1-obj-refs.push: { :$gen, :$offset };
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

                for $xref-obj.decoded.list -> $idx {
                    my $type = $idx[0];
                    given $type {
                        when 0 {}; # free object
                        when 1 {
                            my $offset = $idx[1];
                            my $gen = $idx[2];
                            @type1-obj-refs.push: { :$gen, :$offset };
                        }
                        when 2 {
                            my $obj-num = $idx[1];
                            my $index = $idx[2];
                            %type2-obj-refs{ $obj-num }.push: $index;
                        }
                        default {
                            die "XRef index object type outside range 0..2: $type \@$xref-offset"
                          }
                    }
                }
            }

            $root-obj-ref //= $dict<Root>
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

            if $obj.key eq 'stream' {
                # defer as stream length may be forward references, e.g.
                # 218 0 obj << /Filter /FlateDecode /Length 219 0 R >> stream
                @deferred-objs.push: [ $ind-obj, $offset ];
            }
            else {
                %!ind-obj-idx{ $obj-num }{ $gen-num } //= PDF::Tools::IndObj.new-delegate( :$ind-obj );
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

                %!ind-obj-idx{ $obj-num }{ $gen-num } //= PDF::Tools::IndObj.new-delegate( :$ind-obj, :$encoded );
            };
        }

        for %type2-obj-refs.keys.sort -> $obj-num {
            my $indices = %type2-obj-refs{$obj-num};
            my $container-obj = $.ind-obj( $obj-num.Int, 0);
            my $type2-objects = $container-obj.decoded;

            for $indices.list -> $item {
                my $ind-obj = $type2-objects[ $item ];
                my $obj-num = $ind-obj[0];
                my $gen-num = $ind-obj[1];
                %!ind-obj-idx{ $obj-num }{ $gen-num } //= PDF::Tools::IndObj.new-delegate( :$ind-obj );
            }
        }

        $root-obj-ref.defined
            ?? $!root-obj = $.deref( $root-obj-ref )
            !! die "unable to find root object";
    }
}
