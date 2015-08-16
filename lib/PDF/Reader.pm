use v6;

class PDF::Reader {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::Storage::IndObj;
    use PDF::Storage::Serializer;
    use PDF::Object;
    use PDF::Object::Doc;
    use PDF::Object::Util :to-ast;
    use PDF::Writer;

    has $.input is rw;  # raw PDF image (latin-1 encoding)
    has Str $.file-name;
    has Hash %!ind-obj-idx;
    has $.ast is rw;
    has Bool $.auto-deref is rw = True;
    has Rat $.version is rw;
    has Str $.type is rw;
    has Int $.prev;
    has Int $.size is rw;   #= /Size entry in trailer dict ~ first free object number
    has Bool $.defunct is rw = False;
    has PDF::Object:U $.coercer handles <coerce> = PDF::Object;

    method actions {
        state $actions //= PDF::Grammar::PDF::Actions.new
    }

    method trailer {
        self.install-trailer
           unless %!ind-obj-idx{0}{0}:exists;
        self.ind-obj(0, 0).object;
    }

    method install-trailer(PDF::Object::Dict $object = PDF::Object::Doc.new) {
        my $obj-num = 0;
        my $gen-num = 0;

        #| install the trailer at index (0,0)
        %!ind-obj-idx{$obj-num}{$gen-num} = do {
            $object.reader = self;
            my $ind-obj = PDF::Storage::IndObj.new( :$object, :$obj-num, :$gen-num );
            { :type(1), :$ind-obj }
        }
    }

    #| [PDF 1.7 Table 3.13] Entries in the file trailer dictionary
    method !set-trailer (
        Hash $dict,
        Array :$keys = [ $dict.keys.grep({ $_ ne 'Prev' | 'Size'}) ],
        ) {

        my $trailer = self.trailer;
        for $keys.sort {
            $trailer{$_} = $dict{$_}
                 if $dict{$_}:exists;
        }

        $trailer;
    }

    #| derserialize a json dump
    multi method open( Str $input-file  where m:i/'.json' $/ ) {
        my $ast = from-json( $input-file.IO.slurp );
        die "doesn't contain a pdf struct: $input-file"
            unless $ast.isa(Hash) && ($ast<pdf>:exists);
        $!type = $ast<pdf><header><type> // 'PDF';
        $!version = $ast<pdf><header><version> // 1.2;

        for $ast<pdf><body>.list {

            for .<objects>.list.reverse {
                next unless .<ind-obj>:exists;
                my $ind-obj = .<ind-obj>;
                my ($obj-num, $gen-num, $object) = @( $ind-obj );

                %!ind-obj-idx{$obj-num}{$gen-num} //= {
                    :type(1),
                    :$ind-obj,
                };

            }

            if .<trailer> {
                my $dict = $.coerce( |%(.<trailer>) );
                self!"set-trailer"( $dict.content<dict> );
            }
       }

        $ast;
    }

    #| open the named PDF/FDF file
    multi method open( Str $!file-name, *%opts) {
        $.open( $!file-name.IO.open( :enc<latin-1> ), |%opts );
    }

    multi method open($input-file!, Bool :$repair = False) {
        use PDF::Storage::Input;

        $!input = PDF::Storage::Input.compose( :value($input-file) );

        $.load-header( );
        $.load( $.type, :$repair );
    }

    sub synopsis($input) {
        my $desc = ($input.chars < 60
                    ?? $input
                    !! [~] $input.substr(0, 32), ' ... ', $input.substr(*-20))\
                    .subst(/\n+/, ' ', :g);
        $desc.perl;
    }

    #| load the data for a stream object. Cross check actual size versus expected /Length
    method !fetch-stream-data(Array $ind-obj,           #| primary object
                              $input,                   #| associated input stream
                              :$offset = $ind-obj[3],   #| offset of the object in the input stream
                              :$max-end,                #| upper bound for the end of the stream
        )
    {
        my ($obj-num, $gen-num, $obj-raw) = @$ind-obj;

        $obj-raw.value<encoded> //= do {
            die "stream mandatory /Length field is missing: $obj-num $gen-num R \@$offset "
                unless $obj-raw.value<dict><Length>;

            my $length = $.deref( $obj-raw.value<dict><Length> );
            my $start = $obj-raw.value<start>:delete;
            die "stream Length $length appears too large (> {$max-end - $start}): $obj-num $gen-num R \@$offset"
                if $max-end && $length > $max-end - $start;

            # ensure stream is followed by an 'endstream' marker
            my $tail = $input.substr( $start + $length, 20 );
            if $tail ~~ m{^ (.*?) <PDF::Grammar::PDF::stream-tail>} {
                if $0.chars {
                    # hmm some unprocessed bytes
                    warn "ignoring {$0.chars} bytes before 'endstream' marker: $obj-num $gen-num R \@$offset {synopsis($tail)}"
                }
            }
            else {
                die "unable to locate 'endstream' marker after consuming /Length $length bytes: $obj-num $gen-num R \@$offset {synopsis($tail)}"
            }
            $input.substr( $start, $length );
        };
    }

    #| follow the index. fetch either type-1, or type-2 objects:
    #| type-1: fetch as a top level object from the pdf
    #| type-2: dereference and extract from the containg object
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
                my $max-end = $end - $offset - 1;
                my $input = $.input.substr( $offset, $max-end );
                PDF::Grammar::PDF.subparse( $input, :$.actions, :rule<ind-obj-nibble> )
                    or die "unable to parse indirect object: $obj-num $gen-num R \@$offset {synopsis($input)}";

                $ind-obj = $/.ast.value;
                $actual-obj-num = $ind-obj[0];
                $actual-gen-num = $ind-obj[1];

                self!"fetch-stream-data"($ind-obj, $input, :$offset, :$max-end)
                    if $ind-obj[2].key eq 'stream';
            }
            when 2 {
                # type 2 embedded object
                my $container-obj = $.ind-obj( $idx<ref-obj-num>, 0 ).object;
                my $type2-objects = $container-obj.decoded;

                my $index = $idx<index>;
                my $ind-obj-ref = $type2-objects[ $index ];
                $actual-obj-num = $ind-obj-ref[0];
                $actual-gen-num = 0;
                my $input = $ind-obj-ref[1];

                PDF::Grammar::PDF.subparse( $input, :$.actions, :rule<object> )
                    or die "unable to parse indirect object: $obj-num $gen-num R {synopsis($input)}";
                $ind-obj = [ $actual-obj-num, $actual-gen-num, $/.ast ];
            }
            default {die "unhandled index type: $_"};
        }

        die "index entry was: $obj-num $gen-num R. actual object: $actual-obj-num $actual-gen-num R"
            unless $obj-num == $actual-obj-num && $gen-num == $actual-gen-num;

        $ind-obj;
    }

    #| fetch and stantiate indirect objects. cache against the index
    method ind-obj( Int $obj-num!, Int $gen-num!,
                    :$get-ast = False,  #| get ast data, not formulated objects
                    :$eager = True,     #| fetch object, if not already loaded
        ) {

        die "input pdf has been updated; reader object is now defunct"
             if $!defunct;

        my $idx := %!ind-obj-idx{ $obj-num }{ $gen-num }
            // die "unable to find object: $obj-num $gen-num R";

        my $ind-obj = $idx<ind-obj> //= do {
            return unless $eager;
            my $ind-obj = self!"fetch-ind-obj"($idx, :$obj-num, :$gen-num);
            # only fully stantiate object when needed
            $get-ast ?? $ind-obj !! PDF::Storage::IndObj.new( :$ind-obj, :reader(self) )
        };

        my Bool $is-ind-obj = $ind-obj.isa(PDF::Storage::IndObj);
        my Bool $to-ast = $get-ast && $is-ind-obj;
        my Bool $to-obj = !$get-ast && !$is-ind-obj;

        if $to-ast {
            # regenerate ast from object, if required
            $ind-obj = $ind-obj.ast
        }
        elsif $to-obj && ! $is-ind-obj {
            # upgrade storage to object, if object requested
            $ind-obj = PDF::Storage::IndObj.new( :$ind-obj, :reader(self) );
            $idx<ind-obj> = $ind-obj;
        }
        elsif ! $is-ind-obj  {
            $ind-obj = :$ind-obj
        }

        $ind-obj;
    }

    #| utility method for basic deferencing, e.g.
    #| $reader.deref($root,<Pages>,<Kids>,[0],<Contents>)
    method deref($val is copy, *@ops ) is rw {
        for @ops -> $op {
            $val = self!"ind-deref"($val)
                if $val.isa(Pair);
            $val = do given $op {
                when Array { $val[ $op[0] ] }
                when Str   { $val{ $op } }
                default    {die "bad $.deref arg: {.perl}"}
            };
        }
        $val = self!"ind-deref"($val)
            if $val.isa(Pair);
        $val;
    }

    method !ind-deref(Pair $_! ) {
        return .value unless .key eq 'ind-ref';
        my Int $obj-num = .value[0];
        my Int $gen-num = .value[1];
        $.ind-obj( $obj-num, $gen-num ).object;
    }

    method load-header() {
        use PDF::Grammar::Doc;
        # file should start with: %PDF-n.m, (where n, m are single
        # digits giving the major and minor version numbers).

        my Str $preamble = $.input.substr(0, 8);

        PDF::Grammar::Doc.subparse($preamble, :$.actions, :rule<header>)
            or die "expected file header '%XXX-n.m', got: {synopsis($preamble)}";

        $.version = $/.ast<version>;
        $.type = $/.ast<type>;
    }

    #| Load input in FDF (Form Data Definition) format.
    #| Use full-scan mode, as these are not indexed.
    multi method load('FDF') {
        use PDF::Grammar::FDF;
        use PDF::Grammar::FDF::Actions;
        my $actions = PDF::Grammar::FDF::Actions.new;
        self!"full-scan"( PDF::Grammar::FDF, $actions);
    }

    #| scan the entire PDF, bypass any indices. Populate index with
    #| raw ast indirect objects. Useful if the index is corrupt and/or
    #| the PDF has been hand-created/edited.
    multi method load('PDF', :$repair! where {$repair} ) {
        use PDF::Grammar::PDF;
        use PDF::Grammar::PDF::Actions;
        my $actions = PDF::Grammar::PDF::Actions.new;
        self!"full-scan"( PDF::Grammar::PDF, $actions, :repair);
    }

    #| scan indices, starting at PDF tail. objects can be loaded on demand,
    #| via the $.ind-obj() method.
    multi method load('PDF') is default {
        my Int $tail-bytes = min(1024, $.input.chars);
        my Str $tail = $.input.substr(* - $tail-bytes);

        my %offsets-seen;

        PDF::Grammar::PDF.parse($tail, :$.actions, :rule<postamble>)
            or die "expected file trailer 'startxref ... \%\%EOF', got: {synopsis($tail)}";
        $!prev = $/.ast<startxref>;
        my Int:_ $xref-offset = $!prev;
        my Int $input-bytes = $.input.chars;

        my @obj-idx;
        my $dict;

        while $xref-offset.defined {
            die "xref '/Prev' cycle detected \@$xref-offset"
                if %offsets-seen{$xref-offset}++;
            # see if our cross reference table is already contained in the current tail
            my $xref;
            my &fallback = sub {};
            constant SIZE = 4096;       # big enough to usually contain xref

            if $xref-offset >= $input-bytes - $tail-bytes {
                $xref = $tail.substr( $xref-offset - $input-bytes + $tail-bytes )
            }
            elsif $input-bytes - $tail-bytes - $xref-offset <= SIZE {
                # xref abuts currently read $tail
                my $lumbar-bytes = min(SIZE, $input-bytes - $tail-bytes - $xref-offset);
                $xref = $.input.substr( $xref-offset, $lumbar-bytes) ~ $tail;
            }
            else {
                my Int $xref-len = min(SIZE, $input-bytes - $xref-offset);
                $xref = $.input.substr( $xref-offset, $xref-len );
                &fallback = sub {
                    if $input-bytes - $xref-offset > SIZE {
                        constant SIZE2 = SIZE * 16;
                        # xref not contained in SIZE bytes? subparse a much bigger chunk to make sure
                        $xref-len = min( SIZE2, $input-bytes - $xref-offset - SIZE );
                        $xref ~= $.input.substr( $xref-offset + SIZE, $xref-len );
                        PDF::Grammar::PDF.subparse( $xref, :rule<index>, :$.actions )
                    }
                };
            }

            if $xref ~~ /^'xref'/ {
                # PDF 1.4- xref table followed by trailer
                my $parse = ( PDF::Grammar::PDF.subparse( $xref, :rule<index>, :$.actions )
                              || &fallback() )
                    or die "unable to parse index: $xref";
                my Hash $index = $parse.ast;
                $dict = $.coerce( |%($index<trailer>) );

                my $prev-offset;

                if $index<xref>:exists {
                    for $index<xref>.list {
                        my $obj-num = .<object-first-num>;
                        for @( .<entries> ) {
                            my Int $type = .<type>;
                            my Int $gen-num = .<gen-num>;
                            my Int $offset = .<offset>;

                            given $type {
                                when 0  {} # ignore free objects
                                when 1  { @obj-idx.push: { :$type, :$obj-num, :$gen-num, :$offset } }
                                default { die "unhandled type: $_" }
                            }
                            $obj-num++;
                        }
                    }
                }
            }
            else {
                # PDF 1.5+ XRef Stream
                PDF::Grammar::PDF.subparse($xref, :$.actions, :rule<ind-obj>)
                    or die "ind-obj parse failed \@$xref-offset {synopsis($xref)}";

                my %ast = %( $/.ast );
                my $ind-obj = PDF::Storage::IndObj.new( |%ast, :input($xref), :reader(self) );
                my $xref-obj = $ind-obj.object;
                $dict = $xref-obj;
                @obj-idx.push: $xref-obj.decode-to-stage2.list;
            }

            $xref-offset = $dict<Prev>:exists
                ?? $dict<Prev>
                !! Nil;

            $.size = $dict<Size>:exists
                ?? $dict<Size>
                !! 1; # fix it up later

        }

        my %obj-entries-of-type = @obj-idx.classify({.<type>});

        my @type1-obj-entries = %obj-entries-of-type<1>.list.sort({ $^a<offset> })
            if %obj-entries-of-type<1>:exists;

        for @type1-obj-entries.kv -> $k, $v {
            my Int $obj-num = $v<obj-num>;
            my Int $gen-num = $v<gen-num>;
            my Int $offset = $v<offset>;
            my Int $end = $k + 1 < +@type1-obj-entries ?? @type1-obj-entries[$k + 1]<offset> !! $input-bytes;
            %!ind-obj-idx{ $obj-num }{ $gen-num } = { :type(1), :$offset, :$end };
        }

        my @type2-obj-entries = %obj-entries-of-type<2>.list
        if %obj-entries-of-type<2>:exists;

        for @type2-obj-entries {
            my Int $obj-num = .<obj-num>;
            my Int $gen-num = 0;
            my Int $index = .<index>;
            my Int $ref-obj-num = .<ref-obj-num>;

            %!ind-obj-idx{ $obj-num }{ $gen-num } = { :type(2), :$index, :$ref-obj-num };
        }

        self!"set-trailer"($dict);

        #| don't entirely trust /Size entry in trailer dictionary
        my Int $max-obj-num = max( %!ind-obj-idx.keys>>.Int );
        $.size = $max-obj-num + 1
            if $.size <= $max-obj-num;
    }

    #| bypass any indices. directly parse and reconstruct index fromn objects.
    method !full-scan( $grammar, $actions, :$repair ) {
        temp $actions.get-offsets = True;
        $grammar.parse($.input, :$actions)
            or die "unable to parse document";
        my $ast = $/.ast;
        my Array $body = $ast<body>;

        for $body.list.reverse {
            for .<objects>.list.reverse {
                next unless .key eq 'ind-obj';
                my $ind-obj = .value;
                my ($obj-num, $gen-num, $object, $offset) = @( $ind-obj );

                my $stream-type;
                my $encoded;
                my $dict;
                my $value := $object.value;

                if $object.key eq 'stream' {
                    $dict = $value<dict>;
                    $stream-type = $dict<Type> && $dict<Type>.value;

                    my Int $start = $value<start>;
                    my Int $end = $value<end>;
                    my Int $max-end = $end + 1;

                    # reset/repair stream length
                    $dict<Length> = :int($end - $start + 1)
                        if $repair;

                    self!"fetch-stream-data"($ind-obj, $.input, :$offset, :$max-end);
                }
                else {
                    $dict = $value;
                }

                if $stream-type && $stream-type eq 'XRef' {
                    self!"set-trailer"( $dict, :keys<Root Encrypt Info ID> );
                    # discard existing /Type /XRef stream objects. These are specific to the input PDF
                    next;
                }

                %!ind-obj-idx{$obj-num}{$gen-num} //= {
                    :type(1),
                    :$ind-obj,
                    :$offset,
                };

                if $stream-type && $stream-type eq 'ObjStm' {
                    # Object Stream. Index contents as type 2 objects
                    my $container-obj = $.ind-obj( $obj-num, $gen-num ).object;
                    my Array $type2-objects = $container-obj.decoded;
                    my Int $index = 0;

                    for $type2-objects.list {
                        my $ref-obj-num = $obj-num;
                        my $obj-num2 = .[0];
                        my $gen-num2 = 0;
                        %!ind-obj-idx{$obj-num2}{$gen-num2} //= {
                            :type(2),
                            :$index,
                            :$ref-obj-num,
                        };
                        $index++;
                    }
                }
            }

            if .<trailer> {
                my $dict = $.coerce( |%(.<trailer>) );
                self!"set-trailer"( $dict.content<dict> )
                    if $dict.content<dict>:exists;
            }
        }

        $ast;
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
        Bool :$incremental=False       #| only return updated objects
        ) {
        constant $unpack = True;
        my @object-refs;

        my %objstm-objects;
        for %!ind-obj-idx.values>>.values {
            # implicitly an objstm object, if it contains type2 (compressed) objects
            %objstm-objects{ .<ref-obj-num> }++
                if .<type> == 2;
        }

        for %!ind-obj-idx.pairs.sort {
            my Int $obj-num = .key.Int;

            # discard objstm objects (/Type /ObjStm)
            next
                if $unpack && %objstm-objects{$obj-num};

            for .value.pairs.sort {
                my Int $gen-num = .key.Int;
                my Hash $entry = .value;
                my Int $seq = 0;
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
                if $incremental {

		    # preparing incremental updates. only need to consider fetched objects
		    $final-ast = $.ind-obj($obj-num, $gen-num, :get-ast, :!eager);

		    # the object hasn't been fetched. It cannot have been updated!
		    next unless $final-ast;

		    if $offset && $obj-num {
			# check updated vs original PDF value.
			my $original-ast = self!"fetch-ind-obj"(%!ind-obj-idx{$obj-num}{$gen-num}, :$obj-num, :$gen-num);
			# discard, if not updated
			next if $original-ast eqv $final-ast.value;
                        warn "updated: $obj-num";
		    }
                }
                else {
                    # renegerating PDF. need to eagerly copy updates + unaltered entries
                    # from the full object tree.
                    $final-ast = $.ind-obj($obj-num, $gen-num, :get-ast, :eager)
                        or next;
                }

                my $ind-obj = $final-ast.value[2];

                if $ind-obj<stream>:exists && (my $obj-type = $ind-obj<stream><dict><Type>) {
                    # discard existing /Type /XRef and ObjStm objects.
                    next if $obj-type<name> eq 'XRef' | 'ObjStm';
                }

                $offset ||= 0;
                @object-refs.push: [ $final-ast, $offset + $seq ];
            }
        }

        # preserve input order
        my @objects := @object-refs.sort({$^a[1]}).map: {.[0]};

        if !$incremental && +@objects {
            # Discard Linearization aka "Fast Web View"
            my $first-ind-obj = @objects[0].value[2];
            @objects.shift
                if ($first-ind-obj<dict>:exists)
                && ($first-ind-obj<dict><Linearized>:exists);
        }

        return @objects.item;
    }

    #| get just updated objects. return as objects
    method get-updates() {
        my List $raw-objects = $.get-objects( :incremental );
        $raw-objects.list.map({
            my Int $obj-num = .value[0];
            my Int $gen-num = .value[1];
            $.ind-obj($obj-num, $gen-num).object;
        });
    }

    multi method recompress(Bool :$compress = True) {
        # locate and compress/uncompress stream objects

        for self.get-objects.list {
            my ($type, $ind-obj) = .kv;
            next unless $type eq 'ind-obj';
            my ($obj-type, $obj-raw) = $ind-obj[2].kv;
            if $obj-type eq 'stream' {
                my $is-compressed = $obj-raw<dict><Filter>:exists;
                next if $compress == $is-compressed;
                my Int $obj-num = $ind-obj[0];
                my Int $gen-num = $ind-obj[1];
                # fully stantiate object and adjust compression
                my $object = self.ind-obj( $obj-num, $gen-num).object;
                $compress ?? $object.compress !! $object.uncompress;
            }
        }
    }

    method ast( Bool :$rebuild = False ) {
        my $body = PDF::Storage::Serializer.new.body( self.trailer, :$rebuild );

        :pdf{
            :header{ :$.type, :$.version },
            :body[ $body ],
        }
    }

    #| return an AST for the fully serialized PDF/FDF etc.
    #| suitable as input to PDF::Writer

    #| dump to json
    multi method save-as( $output-path where m:i/'.json' $/,
                          Bool :$rebuild = False,
                          :$ast = $.ast(:$rebuild) ) {
        note "dumping {$output-path}...";
        $output-path.IO.spurt( to-json( $ast ) );
    }

    #| write to PDF/FDF
    multi method save-as( $output-path,
                          Bool :$rebuild = False,
                          :$ast = $.ast(:$rebuild) ) is default {
        note "saving {$output-path}...";
        my $pdf-writer = PDF::Writer.new( :$.input );
        $output-path.IO.spurt( $pdf-writer.write( $ast ), :enc<latin1> );
    }

}
