use v6;

class PDF::Reader {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::Storage::IndObj;
    use PDF::Object;

    has $.input is rw;  # raw PDF image (latin-1 encoding)
    has Hash %!ind-obj-idx;
    has $.root is rw;
    has $.ast is rw;
    has Bool $.auto-deref is rw = False;
    has Rat $.version is rw;
    has Str $.type is rw;
    has PDF::Grammar::PDF::Actions $!actions;
    has $.prev;
    has $.size is rw;   #= /Size entry in trailer dict ~ first free object number

    method actions {
        $!actions //= PDF::Grammar::PDF::Actions.new
    }

    multi method open( Str $input, *%opts) {
        $.open( $input.IO.open( :enc<latin-1> ), |%opts );
    }

    multi method open( $input!) {
        use PDF::Storage::Input;

        $!input = PDF::Storage::Input.compose( :value($input) );

        $.load-header( );
        $.load-xref( );
    }

    method !fetch-ind-obj($idx, :$obj-num, :$gen-num) {
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

                        my $length = $.deref( $obj-raw.value<dict><Length>, :get-ast ).value;
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
        }

        die "index entry was: $obj-num $gen-num R. actual object: $actual-obj-num $actual-gen-num R"
            unless $obj-num == $actual-obj-num && $gen-num == $actual-gen-num;

        $ind-obj;
    }

    method ind-obj( Int $obj-num!, Int $gen-num!,
                    :$type,             #| type assestion
                    :$get-ast=False,    #| get ast data, not formulated objects
                    :$eager=True,       #| only return already loaded objects
        ) {

        my $idx := %!ind-obj-idx{ $obj-num }{ $gen-num }
            // die "unable to find object: $obj-num $gen-num R";

        my $ind-obj = $idx<ind-obj> //= do {
            return unless $eager;
            my $ind-obj = self!"fetch-ind-obj"($idx, :$obj-num, :$gen-num);
            # only fully stantiate object when needed
            $get-ast ?? $ind-obj !! PDF::Storage::IndObj.new( :$ind-obj, :$type, :reader(self) )
        };

        my $is-ind-obj = $ind-obj.isa(PDF::Storage::IndObj);
        my $to-ast = $get-ast && $is-ind-obj;
        my $to-obj = !$get-ast && !$is-ind-obj;

        if $to-ast {
            # regenerate ast from object, if required
            $ind-obj = $ind-obj.ast
        }
        elsif $to-obj {
            # upgrade storage to object, if object requested
            $ind-obj = $idx<ind-obj> = PDF::Storage::IndObj.new( :$ind-obj, :$type, :reader(self) )
                unless $is-ind-obj;
        }
        else {
            $ind-obj = :$ind-obj
                unless $is-ind-obj;
        }

        $ind-obj;
    }

    #| utility method for basic deferencing, e.g.
    #| $reader.deref($root,<Pages>,<Kids>,[0],<Contents>)
    method deref($val is copy, *@ops, :$get-ast) is rw {
        for @ops -> $op {
            $val = self!"ind-deref"($val, :$get-ast)
                if $val.isa(Pair);
            $val = do given $op {
                when Array { $val[ $op[0] ] }
                when Str   { $val{ $op } }
                default    {die "bad $.deref arg: {.perl}"}
            };
        }
        $val = self!"ind-deref"($val, :$get-ast)
            if $val.isa(Pair);
        $val;
    }

    method !ind-deref(Pair $_!, :$get-ast ) {
        return $_ unless .key eq 'ind-ref';
        my $obj-num = .value[0].Int;
        my $gen-num = .value[1].Int;
        my $val = $.ind-obj( $obj-num, $gen-num, :$get-ast );
        $get-ast ?? $val !! $val.object;
    }

    method load-header() {
        # file should start with: %PDF-n.m, (where n, m are single
        # digits giving the major and minor version numbers).
            
        my $preamble = $.input.substr(0, 8);

        PDF::Grammar::PDF.parse($preamble, :$.actions, :rule<header>)
            or die "expected file header '%PDF-n.m', got: {$preamble.perl}";

        $.version = $/.ast<version>;
        $.type = $/.ast<type>;
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
        $!prev = $/.ast.value;
        my $xref-offset = $!prev;

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
                $dict = PDF::Object.compose( |%($trailer-ast<trailer>) );

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
                my $ind-obj = PDF::Storage::IndObj.new( |%ast, :input($xref), :type<XRef>, :reader(self) );
                my $xref-obj = $ind-obj.object;
                $dict = $xref-obj;
                @obj-idx.push: $xref-obj.decode-to-stage2.list;
            }

            $root-ref //= $dict<Root>
                if $dict<Root>:exists;

            $.size = $dict<Size>:exists
                ?? $dict<Size>
                !! 1; # fix it up later

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

        #| don't entirely trust /Size entry in trailer dictionary
        my $max-obj-num = max( %!ind-obj-idx.keys>>.Int );
        $.size = $max-obj-num + 1
            if $.size <= $max-obj-num;

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
    method get-objects(
        Bool :$updates-only=False       #| only return updated objects
        ) {
        constant $unpack = True;
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

                my $final-ast;
                if $updates-only {
                    # preparing incremental updates. only need to consider fetched objects
                    $final-ast = $.ind-obj($obj-num, $gen-num, :get-ast, :!eager);

                    # the object hasn't been fetched. It cannot have been updated!
                    next unless $final-ast;

                    # check updated vs original PDF value.
                    my $original-ast = self!"fetch-ind-obj"(%!ind-obj-idx{$obj-num}{$gen-num}, :$obj-num, :$gen-num);
                    # discard, if not updated
                    next if $original-ast eqv $final-ast.value;
                }
                else {
                    # renegerating PDF. need to eagerly copy updates + unaltered entries
                    # from the full object tree.
                    $final-ast = $.ind-obj($obj-num, $gen-num, :get-ast, :eager)
                        or next;
                }

                my $ind-obj = $final-ast.value[2];

                if my $obj-type = $ind-obj.value<dict><Type> {
                    # discard existing /Type /XRef objects. These are specific to the input PDF
                    next if $obj-type.value eq 'XRef'
                }

                @object-refs.push: [ $final-ast, $offset + $seq ];
            }
        }

        # preserve input order
        my @objects := @object-refs.sort({$^a[1]}).map: {.[0]};

        if !$updates-only && +@objects {
            # Discard Linearization aka "Fast Web View"
            my $first-ind-obj = @objects[0].value[2];
            @objects.shift
                if $first-ind-obj.key eq 'dict'
                && $first-ind-obj.value<Linearized>;
        }

        return @objects.item;
    }

    method get-updates() {
        my $raw-objects = $.get-objects( :updates-only );
        $raw-objects.list.map({
            my $obj-num = .value[0];
            my $gen-num = .value[1];
            $.ind-obj($obj-num, $gen-num).object;
        });
    }

    method ast( ) {
        my $objects = self.get-objects( );

        :pdf{
            :header{ :$.type, :$.version },
            :body{ :$objects },
        };
    }

}
