use v6;

class PDF::Reader {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::Storage::IndObj;
    use PDF::Storage::Serializer;
    use PDF::DAO;
    use PDF::DAO::Doc;
    use PDF::DAO::Util :from-ast, :to-ast;
    use PDF::Writer;
    use PDF::Storage::Input;
    use PDF::Storage::Crypt;

    has $.input is rw;       #= raw PDF image (latin-1 encoding)
    has Str $.file-name;
    has Hash %!ind-obj-idx;
    has $.ast is rw;
    has Bool $.auto-deref is rw = True;
    has Rat $.version is rw;
    has Str $.type is rw;
    has UInt $.prev;
    has UInt $.size is rw;   #= /Size entry in trailer dict ~ first free object number
    has UInt @.xrefs = (0);  #= xref position for each revision in the file
    has PDF::Storage::Crypt $.crypt;

    method actions {
        state $actions //= PDF::Grammar::PDF::Actions.new
    }

    method trailer {
        self.install-trailer
           unless %!ind-obj-idx{0}{0}:exists;
        self.ind-obj(0, 0).object;
    }

    method install-trailer(PDF::DAO::Dict $object = PDF::DAO::Doc.new( :reader(self)) ) {
        my $obj-num = 0;
        my $gen-num = 0;

        #| install the trailer at index (0,0)
        %!ind-obj-idx{$obj-num}{$gen-num} = do {
            my $ind-obj = PDF::Storage::IndObj.new( :$object, :$obj-num, :$gen-num );
            { :type(1), :$ind-obj }
        }
    }

    method !setup-crypt( Str :$password = '') {
	my PDF::DAO::Doc $doc = self.trailer;
	return unless $doc<Encrypt>:exists;
	my $enc = $doc<Encrypt>;

	$!crypt = PDF::Storage::Crypt.delegate-class( :$doc ).new( :$doc );
	$!crypt.authenticate( $password );

	for %!ind-obj-idx.pairs {

	    my $obj-num = +.key
		or next;

	    for .value.pairs {
		my $gen-num = +.key;
		my $idx = .value;

		next if $obj-num == $enc.obj-num
		    && $gen-num == $enc.gen-num;

		if my $ind-obj := $idx<ind-obj> {
		    die "too late to setup encryption: $obj-num $gen-num R"
			if $idx<type> != 0 | 1
			|| $ind-obj.isa(PDF::Storage::IndObj);

		    $!crypt.crypt-ast( (:$ind-obj), :$obj-num, :$gen-num );
		}
	    }
	}

    }

    #| [PDF 1.7 Table 3.13] Entries in the file trailer dictionary
    method !set-trailer (
        Hash $dict,
        Array :$keys = [ $dict.keys.grep({
	    $_ ne 'Prev' | 'Size'                    # Recomputed fields
		| 'Type' | 'DecodeParms' | 'Filter' | 'Index' | 'W' | 'Length' # Unwanted, From XRef Streams
	}) ],
        ) {
	temp $.auto-deref = False;
        my $trailer = self.trailer;

        for $keys.sort {
            $trailer{$_} = from-ast $dict{$_}
                 if $dict{$_}:exists;
        }

        $trailer;
    }

    #| derserialize a json dump
    multi method open( Str $input-file  where m:i/'.json' $/, |c ) {
        use JSON::Fast;
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
                my $dict = PDF::DAO.coerce( |%(.<trailer>) );
                self!set-trailer( $dict.content<dict> );
		self!setup-crypt(|c);
            }
       }

        $ast;
    }

    # process a batch of indirect object updates
    method update( :@entries!, UInt :$!prev, UInt :$!size ) {
        @!xrefs.push: $!prev;

        for @entries -> Hash $entry {
	    my $obj-num = $entry<obj-num>
	        or next;

            my $gen-num = $entry<gen-num>;
            my $type = $entry<type>;

	    given $type {
	        when 0 { # freed
                    %!ind-obj-idx{$obj-num}{$gen-num}:delete;
		}
	        when 1 { # type 1 entry
		    my $ind-obj = $entry<ind-obj>;
		    %!ind-obj-idx{$obj-num}{$gen-num} = {
		        :$type,
		        :$ind-obj,
	            }
		}
                default {
		    die "unable to handle indirect object update of type: $_";
		}
            }
	}
    }

    #| open the named PDF/FDF file
    multi method open( Str $!file-name where {!.isa(PDF::Storage::Input)}, |c) {
        $.open( $!file-name.IO.open( :enc<latin-1> ), |c );
    }

    multi method open($input!, |c) {
        use PDF::Storage::Input;

        $!input = PDF::Storage::Input.coerce( $input );

        $.load-header( );
        $.load( $.type, |c );
    }

    sub synopsis($input) {
        my $desc = ($input.chars < 60
                    ?? $input
                    !! [~] $input.substr(0, 32), ' ... ', $input.substr(*-20))\
                    .subst(/\n+/, ' ', :g);
        $desc.perl;
    }

    #| load the data for a stream object. Cross check actual size versus expected /Length
    method !fetch-stream-data(Array $ind-obj,     #| primary object
                              $input,             #| associated input stream
                              UInt :$offset,      #| offset of the object in the input stream
                              UInt :$max-end,     #| upper bound for the end of the stream
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
            my $tail = $input.substr( $offset + $start + $length, 20 );
            if $tail ~~ m{^ (.*?) <PDF::Grammar::PDF::stream-tail>} {
                if $0.codes {
                    # hmm some unprocessed bytes
                    warn "ignoring {$0.codes} bytes before 'endstream' marker: $obj-num $gen-num R \@$offset {synopsis($tail)}"
                }
            }
            else {
                die "unable to locate 'endstream' marker after consuming /Length $length bytes: $obj-num $gen-num R \@$offset {synopsis($tail)}"
            }
            $input.substr( $offset + $start, $length );
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

                self!fetch-stream-data($ind-obj, $.input, :$offset, :$max-end)
                    if $ind-obj[2].key eq 'stream';

                $!crypt.crypt-ast( (:$ind-obj), :$obj-num, :$gen-num )
                    if $!crypt;
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
    method ind-obj( UInt $obj-num!, UInt $gen-num!,
                    Bool :$get-ast = False,  #| get ast data, not formulated objects
                    Bool :$eager = True,     #| fetch object, if not already loaded
        ) {

        my $idx := %!ind-obj-idx{ $obj-num }{ $gen-num }
            // die "unable to find object: $obj-num $gen-num R";

        my $ind-obj = $idx<ind-obj> //= do {
            return unless $eager;
            my $_ind-obj = self!fetch-ind-obj($idx, :$obj-num, :$gen-num);
            # only fully stantiate object when needed
            $get-ast ?? $_ind-obj !! PDF::Storage::IndObj.new( :ind-obj($_ind-obj), :reader(self) )
        };

        my Bool $is-ind-obj = $ind-obj.isa(PDF::Storage::IndObj);
        my Bool $to-ast = $get-ast && $is-ind-obj;
        my Bool $to-obj = ?(!$get-ast && !$is-ind-obj);

        if $to-ast {
            # regenerate ast from object, if required
            $ind-obj = $ind-obj.ast
        }
        elsif $to-obj {
            # upgrade storage to object, if object requested
            $ind-obj = PDF::Storage::IndObj.new( :$ind-obj, :reader(self) );
            $idx<ind-obj> = $ind-obj;
        }
        elsif ! $is-ind-obj  {
            # immediate return to work around rakudo RT#126369
            return :$ind-obj;
        }

        $ind-obj;
    }

    #| utility method for basic deferencing, e.g.
    #| $reader.deref($root,<Pages>,<Kids>,[0],<Contents>)
    method deref($val is copy, **@ops ) is rw {
        for @ops -> $op {
            $val = self!ind-deref($val)
                if $val.isa(Pair);
            $val = do given $op {
                when Array { $val[ $op[0] ] }
                when Str   { $val{ $op } }
                default    {die "bad $.deref arg: {.perl}"}
            };
        }
        $val = self!ind-deref($val)
            if $val.isa(Pair);
        $val;
    }

    method !ind-deref(Pair $_! ) {
        return .value unless .key eq 'ind-ref';
        my UInt $obj-num = .value[0];
        my UInt $gen-num = .value[1];
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
        self!full-scan( PDF::Grammar::FDF, $actions);
    }

    #| scan the entire PDF, bypass any indices. Populate index with
    #| raw ast indirect objects. Useful if the index is corrupt and/or
    #| the PDF has been hand-created/edited.
    multi method load('PDF', :$repair! where {$repair}, |c ) {
        self!full-scan( PDF::Grammar::PDF, $.actions, :repair, |c );
    }

    #| scan indices, starting at PDF tail. objects can be loaded on demand,
    #| via the $.ind-obj() method.
    multi method load('PDF', |c) is default {
        my UInt $tail-bytes = min(1024, $.input.codes);
        my Str $tail = $.input.substr(* - $tail-bytes);

        my %offsets-seen;
        @!xrefs = [];

        PDF::Grammar::PDF.parse($tail, :$.actions, :rule<postamble>)
            or die "expected file trailer 'startxref ... \%\%EOF', got: {synopsis($tail)}";
        $!prev = $/.ast<startxref>;
        my UInt:_ $xref-offset = $!prev;
        my UInt $input-bytes = $.input.codes;

        my @obj-idx;
        my $dict;

        while $xref-offset.defined {
	    @!xrefs.unshift: $xref-offset;
            die "xref '/Prev' cycle detected \@$xref-offset"
                if %offsets-seen{$xref-offset}++;
            # see if our cross reference table is already contained in the current tail
            my Str $xref;
            my &fallback = sub {};
            constant SIZE = 4096;       # big enough to usually contain xref

            if $xref-offset >= $input-bytes - $tail-bytes {
                $xref = $.input.substr( $xref-offset, $tail-bytes )
            }
            elsif $input-bytes - $tail-bytes - $xref-offset <= SIZE {
                # xref abuts currently read $tail
                my UInt $lumbar-bytes = min(SIZE, $input-bytes - $tail-bytes - $xref-offset);
                $xref = $.input.substr( $xref-offset, $lumbar-bytes) ~ $tail;
            }
            else {
                my UInt $xref-len = min(SIZE, $input-bytes - $xref-offset);
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
                $dict = PDF::DAO.coerce( |%($index<trailer>), :reader(self) );
                self!set-trailer($dict);

                my $prev-offset;

                if $index<xref>:exists {
                    for $index<xref>.list {
                        my $obj-num = .<obj-first-num>;
                        for @( .<entries> ) {
                            my UInt $type = .<type>;
                            my UInt $gen-num = .<gen-num>;
                            my UInt $offset = .<offset>;

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
                self!set-trailer($dict);
                @obj-idx.append: $xref-obj.decode-to-stage2.list;
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
            my UInt $obj-num = $v<obj-num>;
            my UInt $gen-num = $v<gen-num>;
            my UInt $offset = $v<offset>;
            my UInt $end = $k + 1 < +@type1-obj-entries ?? @type1-obj-entries[$k + 1]<offset> !! $input-bytes;
            %!ind-obj-idx{ $obj-num }{ $gen-num } = { :type(1), :$offset, :$end };
        }

	self!setup-crypt(|c);

        my @type2-obj-entries = %obj-entries-of-type<2>.list
        if %obj-entries-of-type<2>:exists;

        for @type2-obj-entries {
            my UInt $obj-num = .<obj-num>;
            my UInt $gen-num = 0;
            my UInt $index = .<index>;
            my UInt $ref-obj-num = .<ref-obj-num>;

            %!ind-obj-idx{ $obj-num }{ $gen-num } = { :type(2), :$index, :$ref-obj-num };
        }

        #| don't entirely trust /Size entry in trailer dictionary
        my UInt $max-obj-num = max( %!ind-obj-idx.keys>>.Int );
        $.size = $max-obj-num + 1
            if $.size <= $max-obj-num;
    }

    #| bypass any indices. directly parse and reconstruct index fromn objects.
    method !full-scan( $grammar, $actions, Bool :$repair, |c) {
        temp $actions.get-offsets = True;
        $grammar.parse(~$.input, :$actions)
            or die "unable to parse document";
        my $ast = $/.ast;
        my Array $body = $ast<body>;

        for $body.list.reverse {

            for .<objects>.list.reverse {
                next unless .key eq 'ind-obj';
                my $ind-obj = .value;
                my ($obj-num, $gen-num, $object, $offset) = @( $ind-obj );

                my $dict;
                my $stream-type;
                my $value := $object.value;

                if $object.key eq 'stream' {
                    $dict = $value<dict>;
                    $stream-type = $dict<Type> && $dict<Type>.value;

                    # reset/repair stream length
                    $dict<Length> = :int($value<encoded>.codes)
                        if $repair;

		    if $stream-type && $stream-type eq 'XRef' {
			self!set-trailer( $dict, :keys[<Root Encrypt Info ID>] );
			self!setup-crypt(|c);
			# discard existing /Type /XRef stream objects. These are specific to the input PDF
			next;
		    }

                }
                else {
                    $dict = $value;
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
                    my UInt $index = 0;

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
                my $dict = PDF::DAO.coerce( |%(.<trailer>) );
                self!set-trailer( $dict.content<dict> );
		self!setup-crypt(|c);
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
        Bool :$incremental       #| only return updated objects
        ) {
        constant $unpack = True;
        my @object-refs;

        my %objstm-objects;
        for %!ind-obj-idx.values.map( *.values.Slip ) {
            # implicitly an objstm object, if it contains type2 (compressed) objects
            %objstm-objects{ .<ref-obj-num> }++
                if .<type> == 2;
        }

        for %!ind-obj-idx.pairs.sort {
            my UInt $obj-num = .key.Int;

            # discard objstm objects (/Type /ObjStm)
            next
                if $unpack && %objstm-objects{$obj-num};

            for .value.pairs.sort {
                my UInt $gen-num = .key.Int;
                my Hash $entry = .value;
                my UInt $seq = 0;
                my UInt $offset;

                given $entry<type> {
                    when 0 {
                        # type 0 freed object
                        next;
                    }
                    when 1 {
                        # type 1 regular top-level/inuse object
                        $offset = $entry<offset>
                            if $entry<offset>:exists
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

                my $ast;
                if $incremental {

		    # preparing incremental updates. only need to consider fetched objects
		    $ast = $.ind-obj($obj-num, $gen-num, :get-ast, :!eager);

		    # the object hasn't been fetched. It cannot have been updated!
		    next unless $ast;

		    if $offset && $obj-num {
			# check updated vs original PDF value.
			my $original-ast = self!fetch-ind-obj(%!ind-obj-idx{$obj-num}{$gen-num}, :$obj-num, :$gen-num);
			# discard, if not updated
			next if $original-ast eqv $ast.value;
		    }
                }
                else {
                    # renegerating PDF. need to eagerly copy updates + unaltered entries
                    # from the full object tree.
                    $ast = $.ind-obj($obj-num, $gen-num, :get-ast, :eager)
                        or next;
                }

                my $ind-obj = $ast.value[2];

                if $ind-obj<stream>:exists && (my $obj-type = $ind-obj<stream><dict><Type>) {
                    # discard existing /Type /XRef and ObjStm objects.
                    next if $obj-type<name> eq 'XRef' | 'ObjStm';
                }

                $offset //= 0;
                @object-refs.push( ($offset + $seq) => $ast );
            }
        }

        # preserve input order
        my @objects = @object-refs.list.sort(*.key).map: *.value;

        if !$incremental && +@objects {
            # Discard Linearization aka "Fast Web View"
            my $first-ind-obj = @objects[0].value[2];
            @objects.shift
                if ($first-ind-obj<dict>:exists)
                && ($first-ind-obj<dict><Linearized>:exists);
        }

        return @objects;
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
        my $serializer = PDF::Storage::Serializer.new( :reader(self) );

        my Array $body = $rebuild
            ?? $serializer.body( self.trailer )
            !! $serializer.body( :$rebuild );

        self.crypt.crypt-ast('body', $body)
            if self.crypt;

        :pdf{
            :header{ :$.type, :$.version },
            :$body,
        }
    }

    #| return an AST for the fully serialized PDF/FDF etc.
    #| suitable as input to PDF::Writer

    #| dump to json
    multi method save-as( $output-path where m:i/'.json' $/,
                          :$ast is copy, |c ) {
        $ast //= $.ast(|c);
        note "dumping {$output-path}...";
        use JSON::Fast;
        $output-path.IO.spurt( to-json( $ast ) );
    }

    #| write to PDF/FDF
    multi method save-as( $output-path,
                          :$ast is copy, |c ) is default {
        $ast //= $.ast(|c);
        note "saving {$output-path}...";
        my $pdf-writer = PDF::Writer.new( :$.input );
        $output-path.IO.spurt( $pdf-writer.write( $ast ), :enc<latin1> );
    }

}

