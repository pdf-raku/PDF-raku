use v6;

my sub synopsis($input) {
    my \desc = (
        $input.chars < 60
            ?? $input
            !! [~] $input.substr(0, 32), ' ... ', $input.substr(*-20)
    ).subst(/\n+/, ' ', :g);
    desc.perl;
}

class X::PDF::BadDump is Exception {
    has Str $.input-file is required;
    method message {"File doesn't contain a top-level 'cos' struct: $!input-file"}
}

class X::PDF::BadHeader is Exception {
    has Str $.preamble is required;
    method message {"Expected file header '%XXX-n.m', got: {synopsis($!preamble)}"}
}

class X::PDF::BadTrailer is Exception {
    has Str $.tail is required;
    method message {"Expected file trailer 'startxref ... \%\%EOF', got: {synopsis($!tail)}"}
}

class X::PDF::BadXRef is Exception {}

class X::PDF::BadXRef::Parse is X::PDF::BadXRef {
    has Str $.xref is required;
    method message {"Unable to parse index: {synopsis($!xref)}"}
}

class X::PDF::BadXRef::Entry is X::PDF::BadXRef {
    has UInt $.obj-num;
    has UInt $.gen-num;
    has UInt $.actual-obj-num;
    has UInt $.actual-gen-num;
    method message {"Cross reference mismatch. Index entry was: $!obj-num $!gen-num R. actual object: $!actual-obj-num $!actual-gen-num R. Please inform the author of the PDF and/or try opening this PDF with :repair"}
}

class X::PDF::BadXRef::Section is X::PDF::BadXRef {
    has UInt $.obj-count;
    has UInt $.entry-count;
    method message {"xref section size mismatch. Expected $!obj-count entries, got $!entry-count"}
}

class X::PDF::ParseError is Exception {
    has Str $.input is required;
    method message {"Unable to parse PDF document: {synopsis($!input)}"}
}

class X::PDF::BadIndirectObject is Exception {
    has UInt $.obj-num;
    has UInt $.gen-num;
    has UInt $.offset  is required;
    has Str  $.details is rw;
    method message {
        my Str $ind-ref = $!obj-num ?? "$!obj-num $!gen-num R " !! "";
        "Error processing indirect object {$ind-ref}at byte offset $!offset:\n$!details"
    }
}

class X::PDF::BadIndirectObject::Parse is X::PDF::BadIndirectObject {
    has Str $.input is required;
    method message {
        $.details = "unable to parse indirect object: " ~ synopsis($.input);
        nextsame;
    }
}

class PDF::Reader {

    use PDF::Grammar::COS;
    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::IO;
    use PDF::IO::IndObj;
    use PDF::IO::Serializer;
    use PDF::COS;
    use PDF::COS::Dict;
    use PDF::COS::Util :from-ast, :to-ast;
    use PDF::Writer;
    use JSON::Fast;

    has $.input is rw;       #= raw PDF image (latin-1 encoding)
    has Str $.file-name;
    has Hash %!ind-obj-idx;
    has Bool $.auto-deref is rw = True;
    has Rat $.version is rw;
    has Str $.type is rw;    #= 'PDF', 'FDF', etc...
    has uint $.prev;
    has uint $.size is rw;   #= /Size entry in trailer dict ~ first free object number
    has uint64 @.xrefs = (0);  #= xref position for each revision in the file
    has $.crypt;
    my enum IndexType <Free External Embedded>;

    method actions {
        state $actions //= PDF::Grammar::PDF::Actions.new
    }

    method trailer {
        Proxy.new(
            FETCH => sub ($) {
                self!install-trailer
                    without %!ind-obj-idx{"0 0"};
                self.ind-obj(0, 0).object;
            },
            STORE => sub ($, \obj) {
                self!install-trailer(obj);
            },
        );
    }

    method !install-trailer(PDF::COS::Dict $object = PDF::COS::Dict.new( :reader(self) ) ) {
        %!ind-obj-idx{"0 0"} = do {
            my PDF::IO::IndObj $ind-obj .= new( :$object, :obj-num(0), :gen-num(0) );
            %( :type(External), :$ind-obj );
        }
    }

    method !setup-crypt(Str :$password = '') {
	my Hash $doc = self.trailer;
	return without $doc<Encrypt>;

	$!crypt = (require ::('PDF::IO::Crypt::PDF')).new( :$doc );
	$!crypt.authenticate( $password );
	my \enc = $doc<Encrypt>;
        my \enc-obj-num = enc.obj-num;
        my \enc-gen-num = enc.gen-num;

	for %!ind-obj-idx.pairs {

            my UInt ($obj-num, $gen-num) = .key.split(' ')>>.Int;
            next unless $obj-num;
	    my Hash $idx = .value;

            # skip the encryption dictionary, if it's an indirect object
	    if $obj-num == enc-obj-num
	    && $gen-num == enc-gen-num {
		$idx<is-enc-dict> = True;
	    }
	    else {
		with $idx<ind-obj> -> $ind-obj {
		    die "too late to setup encryption: $obj-num $gen-num R"
		        if $idx<type> != Free | External
		        || $ind-obj.isa(PDF::IO::IndObj);

		    $!crypt.crypt-ast( (:$ind-obj), :$obj-num, :$gen-num, :mode<decrypt> );
		}
	    }
	}
    }

    #| [PDF 1.7 Table 3.13] Entries in the file trailer dictionary
    method !set-trailer (
        Hash $dict,
        Array :$keys = [ $dict.keys.grep: {
	    $_ !~~ 'Prev'|'Size'                    # Recomputed fields
		|'Type'|'DecodeParms'|'Filter'|'Index'|'W'|'Length'|'XRefStm' # Unwanted, From XRef Streams
	} ],
        ) {
	temp $.auto-deref = False;
        my Hash $trailer = self.trailer;

        for $keys.sort -> \k {
            $trailer{k} = from-ast $_
                 with $dict{k};
        }

        $trailer;
    }

    #| open the named PDF/FDF file
    multi method open( Str $!file-name where {!.isa(PDF::IO)}, |c) {
        $.open( $!file-name.IO, |c );
    }

    #| deserialize a JSON dump
    multi method open(IO::Path $input-path  where .extension.lc eq 'json', |c ) {
        my \ast = from-json( $input-path.IO.slurp );
        my \root = ast<cos> // ast<pdf> if ast.isa(Hash);
        die X::PDF::BadDump.new( :input-file($input-path.absolute) )
            without root;
        $!type = root<header><type> // 'PDF';
        $!version = root<header><version> // 1.2;

        for root<body>.list {

            for .<objects>.list.reverse {
                with .<ind-obj> -> $ind-obj {
                    (my UInt $obj-num, my UInt $gen-num) = $ind-obj.list;

                    %!ind-obj-idx{"$obj-num $gen-num"} //= %(
                        :type(External),
                        :$ind-obj,
                    );
                }
            }

            with .<trailer> {
                my Hash $dict = PDF::COS.coerce( |$_ );
                self!set-trailer( $dict.content<dict> );
		self!setup-crypt(|c);
            }
       }

        ast;
    }

    # process a batch of indirect object updates
    method update( :@entries!, UInt :$!prev, UInt :$!size ) {
        @!xrefs.push: $!prev;

        for @entries -> Hash $entry {
	    my UInt $obj-num = $entry<obj-num>
	        or next;

            my UInt $gen-num = $entry<gen-num>;
            my UInt $type = $entry<type>;

	    given $type {
	        when Free {
                    %!ind-obj-idx{"$obj-num $gen-num"}:delete;
		}
	        when External {
		    my $ind-obj = $entry<ind-obj>;
		    %!ind-obj-idx{"$obj-num $gen-num"} = %(
		        :$type,
		        :$ind-obj,
                    );
		}
                default {
		    die "unable to handle indirect object update of type: $_";
		}
            }
	}
    }

    multi method open($input!, |c) {
        $!input = PDF::IO.coerce( $input );
        $.load-header( );
        $.load-cos( $.type, |c );
    }

    #| load the data for a stream object. Cross check actual size versus expected /Length
    method !fetch-stream-data(@ind-obj,           #| primary object
                              $input,             #| associated input stream
                              UInt :$offset,      #| offset of the object in the input stream
                              UInt :$max-end,     #| upper bound for the end of the stream
        )
    {
        my (UInt $obj-num, UInt $gen-num, $obj-raw) = @ind-obj;

        $obj-raw.value<encoded> //= do {
            my UInt \from = $obj-raw.value<start>:delete;
            my UInt \length = $.deref( $obj-raw.value<dict><Length> )
                // die X::PDF::BadIndirectObject.new(:$obj-num, :$gen-num, :$offset,
                                                     :details("stream mandatory /Length field is missing")
                                                    );

            with $max-end {
                die X::PDF::BadIndirectObject.new(
                    :$obj-num, :$gen-num, :$offset,
                    :details("stream Length {length} appears too large (> {$max-end - from})"),
                ) if length > $_ - from;
            }

            # ensure stream is followed by an 'endstream' marker
            my Str \tail = $input.substr( $offset + from + length, 20 );
            if tail ~~ m{<PDF::Grammar::PDF::stream-tail>} {
                warn X::PDF::BadIndirectObject.new(
                    :$obj-num, :$gen-num, :$offset,
                    :details("ignoring {$/.from} bytes before 'endstream' marker")
                    ) if $/.from;
            }
            else {
                die X::PDF::BadIndirectObject.new(
                    :$obj-num, :$gen-num, :$offset,
                    :details("unable to locate 'endstream' marker after consuming /Length {length} bytes")
                    );
            }

	    length
		?? $input.substr( $offset + from, length )
		!! '';
        };
    }

    #| follow the index. fetch either type-1, or type-2 objects:
    #| type-1: fetch as a top level object from the pdf
    #| type-2: dereference and extract from the containing object
    method !fetch-ind-obj(% (:$type!, :$ind-obj is copy,
                             :$offset, :$end,                       # type-1
                             :$index, :$ref-obj-num, :$is-enc-dict  # type-2
                            ), :$obj-num, :$gen-num) {
        # stantiate the object
        my $actual-obj-num;
        my $actual-gen-num;

        given $type {
            when External {
                my UInt $max-end = $offset >= $end
                    ?? die "Attempt to fetch object $obj-num $gen-num R at byte offset $offset, past end of PDF ($end bytes)"
                    !! $end - $offset - 1;
                my $input = $.input.substr( $offset, $max-end );
                PDF::Grammar::PDF.subparse( $input, :$.actions, :rule<ind-obj-nibble> )
                    or die X::PDF::BadIndirectObject::Parse.new( :$obj-num, :$gen-num, :$offset, :$input);

                $ind-obj = $/.ast.value;

                $actual-obj-num = $ind-obj[0];
                $actual-gen-num = $ind-obj[1];

                self!fetch-stream-data($ind-obj, $.input, :$offset, :$max-end)
                    if $ind-obj[2].key eq 'stream';

                $!crypt.crypt-ast( (:$ind-obj), :$obj-num, :$gen-num, :mode<decrypt> )
                    if $!crypt && ! $is-enc-dict;
            }
            when Embedded {
                my subset ObjStm of Hash where { $_ eq 'ObjStm' with .<Type> }
                my ObjStm \container-obj = $.ind-obj( $ref-obj-num, 0 ).object;
                my \embedded-objects = container-obj.decoded;

                my Array \ind-obj-ref = embedded-objects[$index];
                $actual-obj-num = ind-obj-ref[0];
                $actual-gen-num = 0;
                my $input = ind-obj-ref[1];

                PDF::Grammar::PDF.subparse( $input, :$.actions, :rule<object> )
                    or die X::PDF::BadIndirectObject::Parse.new( :$obj-num, :$gen-num, :$input);
                $ind-obj = [ $actual-obj-num, $actual-gen-num, $/.ast ];
            }
            default {die "unhandled index type: $_"};
        }

        die X::PDF::BadXRef::Entry.new( :$obj-num, :$actual-obj-num, :$gen-num, :$actual-gen-num )
            unless $obj-num == $actual-obj-num && $gen-num == $actual-gen-num;

        $ind-obj;
    }

    #| fetch and stantiate indirect objects. cache against the index
    method ind-obj( UInt $obj-num!, UInt $gen-num!,
                    Bool :$get-ast = False,  #| get ast data, not formulated objects
                    Bool :$eager = True,     #| fetch object, if not already loaded
        ) {

        my Hash $idx := %!ind-obj-idx{"$obj-num $gen-num"}
            // die "unable to find object: $obj-num $gen-num R";

        my $ind-obj = $idx<ind-obj> //= do {
            return unless $eager;
            my \ind-obj = self!fetch-ind-obj($idx, :$obj-num, :$gen-num);
            # only fully stantiate object when needed
            $get-ast ?? ind-obj !! PDF::IO::IndObj.new( :ind-obj(ind-obj), :reader(self) )
        };

        my Bool \is-ind-obj = $ind-obj.isa(PDF::IO::IndObj);
        my Bool \to-ast = $get-ast && is-ind-obj;

        if to-ast {
            # regenerate ast from object, if required
            $ind-obj = $ind-obj.ast
        }
        else {
            my Bool \to-obj = ?(!$get-ast && !is-ind-obj);
            if to-obj {
                # upgrade storage to object, if object requested
                $ind-obj = PDF::IO::IndObj.new( :$ind-obj, :reader(self) );
                $idx<ind-obj> = $ind-obj;
            }
            elsif ! is-ind-obj  {
                $ind-obj := :$ind-obj;
            }
        }

        $ind-obj;
    }

    #| utility method for basic deferencing, e.g.
    #| $reader.deref($root,<Pages>,<Kids>,[0],<Contents>)
    method deref($val is copy, **@ops ) is rw {
        for @ops -> \op {
            $val = self!ind-deref($val)
                if $val.isa(Pair);
            $val = do given op {
                when Array { $val[ .[0] ] }
                when Str   { $val{ $_ } }
                default    {die "bad \$.deref arg: {.perl}"}
            };
        }
        $val = self!ind-deref($val)
            if $val.isa(Pair);
        $val;
    }

    method !ind-deref(Pair $_! ) {
        return .value unless .key eq 'ind-ref';
        my UInt \obj-num = .value[0];
        my UInt \gen-num = .value[1];
        $.ind-obj( obj-num, gen-num ).object;
    }

    method load-header() {
        # file should start with: %PDF-n.m, (where n, m are single
        # digits giving the major and minor version numbers).

        my Str $preamble = $.input.substr(0, 8);

        PDF::Grammar::COS.subparse($preamble, :$.actions, :rule<header>)
            or die X::PDF::BadHeader.new( :$preamble );

        $.version = $/.ast<version>;
        $.type = $/.ast<type>;
    }

    #| Load input in FDF (Form Data Definition) format.
    #| Use full-scan mode, as these are not indexed.
    multi method load-cos('FDF') {
        self!full-scan((require ::('PDF::Grammar::FDF')), $.actions);
    }

    #| scan the entire PDF, bypass any indices. Populate index with
    #| raw ast indirect objects. Useful if the index is corrupt and/or
    #| the PDF has been hand-created/edited.
    multi method load-cos('PDF', :$repair! where .so, |c ) {
        self!full-scan( PDF::Grammar::PDF, $.actions, :repair, |c );
    }

    multi method load-cos('PDF', |c ) {
        self!load-index( PDF::Grammar::PDF, $.actions, |c );
    }

    multi method load-cos($type, |c) is default {
        self!load-index(PDF::Grammar::COS, $.actions, |c );
    }

    method !locate-xref($input-bytes, $tail-bytes, $tail, $offset, $fallback is rw) {
	my str $xref;
	constant SIZE = 4096;       # big enough to usually contain xref

	if $offset >= $input-bytes - $tail-bytes {
	    $xref = $.input.substr( $offset, $tail-bytes )
	}
	elsif $input-bytes - $tail-bytes - $offset <= SIZE {
	    # xref abutts currently read $tail
	    my UInt $lumbar-bytes = min(SIZE, $input-bytes - $tail-bytes - $offset);
	    $xref = $.input.substr( $offset, $lumbar-bytes) ~ $tail;
	}
	else {
	    my UInt $xref-len = min(SIZE, $input-bytes - $offset);
	    $xref = $.input.substr( $offset, $xref-len );
	    $fallback = sub (Numeric $_, Str $xref is rw) {
                when 1 {
                    # first retry: increase buffer size
		    if $input-bytes - $offset > SIZE {
		        constant SIZE2 = SIZE * 15;
		        # xref not contained in SIZE bytes? subparse a much bigger chunk
		        $xref-len = min( SIZE2, $input-bytes - $offset - SIZE );
		        $xref ~= $.input.substr( $offset + SIZE, $xref-len );
		    }
                }
                when 2 {
                    # second retry: read through to the tail
		    $xref ~= $.input.substr( $offset + SIZE + $xref-len);
                }
                default {
                    fail;
                }
	    };
	}
	$xref;
    }

    #| load PDF 1.4- xref table followed by trailer
    method !load-xref-table(Str $xref is copy, $dict is rw, :$offset, :&fallback) {
	my $parse = PDF::Grammar::PDF.subparse( $xref, :rule<index>, :$.actions );
        $parse ||= (
            PDF::Grammar::PDF.subparse( &fallback(1, $xref), :rule<index>, :$.actions )
            || PDF::Grammar::PDF.subparse( &fallback(2, $xref), :rule<index>, :$.actions )
        ) if &fallback;

	die X::PDF::BadXRef::Parse.new( :$offset, :$xref )
            unless $parse;

	my \index = $parse.ast;
	my @idx;

	with index<xref> {
	    for .list {
                warn X::PDF::BadXRef::Section.new( :obj-count(.<obj-count>), :entry-count(+.<entries>))
                    unless .<obj-count> == +.<entries>;

		my uint $obj-num = .<obj-first-num>;
		with .<entries> {
                    my uint $n = .elems;
                    loop (my uint $i = 0; $i < $n; $i++) {
                        my uint64 $offset  = .[$i;0];
                        my uint64 $gen-num = .[$i;1];
                        my uint64 $type    = .[$i;2];

                        if $offset && $type == External {
                            my uint64 @xref = $obj-num, $type, $offset, $gen-num;
                            @idx.push: @xref;
                        }
                        $obj-num++;
                    }
		}
	    }
	}

	$dict = PDF::COS.coerce( |index<trailer>, :reader(self) );

	@idx;
    }

    #| load a PDF 1.5+ XRef Stream
    method !load-xref-stream(Str $xref is copy, $dict is rw, UInt :$offset, :&fallback) {
        my $parse = PDF::Grammar::PDF.subparse($xref, :$.actions, :rule<ind-obj>);
        $parse ||= (
	    PDF::Grammar::PDF.subparse(&fallback(1, $xref), :$.actions, :rule<ind-obj>)
	    || PDF::Grammar::PDF.subparse(&fallback(2, $xref), :$.actions, :rule<ind-obj>)
        ) if &fallback;

	die X::PDF::BadIndirectObject::Parse.new( :$offset, :input($xref))
            unless $parse;

	my %ast = $parse.ast;
	my PDF::IO::IndObj $ind-obj .= new( |%ast, :input($xref), :reader(self) );
        my subset XRef of Hash where { $_ eq 'XRef' with .<Type> }
	$dict = my XRef $ = $ind-obj.object;
	$dict.decode-index.list;
    }

    #| scan indices, starting at PDF tail. objects can be loaded on demand,
    #| via the $.ind-obj() method.
    method !load-index($grammar, $actions, |c) is default {
        my UInt \tail-bytes = min(1024, $.input.codes);
        my Str $tail = $.input.substr(* - tail-bytes);

        my UInt %offsets-seen;
        @!xrefs = [];

        $grammar.parse($tail, :$actions, :rule<postamble>)
            or die X::PDF::BadTrailer.new( :$tail );

        $!prev = $/.ast<startxref>;
        my UInt:_ $offset = $!prev;
        my UInt \input-bytes = $.input.codes;

        my array @obj-idx;
        my Hash $dict;

        while $offset.defined {
	    @!xrefs.unshift: $offset;
            die "xref '/Prev' cycle detected \@$offset"
                if %offsets-seen{$offset}++;
            # see if our cross reference table is already contained in the current tail
	    my Str \xref = self!locate-xref(input-bytes, tail-bytes, $tail, $offset, my &fallback);

	    @obj-idx.append: xref ~~ m:s/^ xref/
		?? self!load-xref-table( xref, $dict, :&fallback, :$offset)
		!! self!load-xref-stream(xref, $dict, :&fallback, :$offset);

	    self!set-trailer: $dict;

            $offset = do with $dict<Prev> { $_ } else { Nil };
            $.size  = do with $dict<Size> { $_ } else { 1 };

            with $dict<XRefStm> {
                # hybrid 1.4 / 1.5 with a cross-reference stream
                my $xref-dict = {};
                my Str \xref-stm = self!locate-xref(input-bytes, tail-bytes, $tail, $_, my &fallback);
                @obj-idx.append: self!load-xref-stream(xref-stm, $xref-dict, :&fallback, :offset($_));
            }

        }

        enum ( :ObjNum(0), :Type(1),
               :Offset(2), :GenNum(3),     # Type 1 (External) Objects
               :RefObjNum(2), :Index(3)    # Type 2 (Embedded) Objects
            );

        my %obj-entries-of-type = @obj-idx.classify: *.[Type];

        my @type1-obj-entries = .list.sort({ $^a[Offset] })
            with %obj-entries-of-type<1>;

        for @type1-obj-entries.kv -> \k, $_ {
            my uint64 $end = k + 1 < +@type1-obj-entries ?? @type1-obj-entries[k + 1][Offset] !! input-bytes;
            my uint64 $offset = .[Offset];
            %!ind-obj-idx{.[ObjNum] ~ ' ' ~ .[GenNum]} = %( :type(External), :$offset, :$end );
        }

	self!setup-crypt(|c);

        my @embedded-obj-entries = .list
            with %obj-entries-of-type<2>;

        for @embedded-obj-entries {
            my UInt $obj-num = .[ObjNum];
            my UInt $index = .[Index];
            my UInt $ref-obj-num = .[RefObjNum];
            my UInt $gen-num = 0;

            %!ind-obj-idx{"$obj-num $gen-num"} = %( :type(Embedded), :$index, :$ref-obj-num );
        }

        #| don't entirely trust /Size entry in trailer dictionary
        my Str \max-idx = max( %!ind-obj-idx.keys );
        my UInt \actual-size = max-idx.split(' ')[0].Int;
        $.size = actual-size + 1
            if $.size <= actual-size;
    }

    #| bypass any indices. directly parse and reconstruct index from objects.
    method !full-scan( $grammar, $actions, Bool :$repair, |c) {
        temp $actions.get-offsets = True;
        my Str $input = ~$.input;
        $grammar.parse($input, :$actions)
            or die X::PDF::ParseError.new( :$input );

        my %ast = $/.ast;
        my Hash @body = %ast<body>.list;

        for @body.reverse {
	    my Pair @objects = .<objects>.list;

            for @objects.reverse {
                next unless .key eq 'ind-obj';
                my @ind-obj = .value.list;
                my (UInt $obj-num, UInt $gen-num, $object, UInt $offset) = @ind-obj;

                my $stream-type;

                if $object.key eq 'stream' {
                    my \stream = $object.value;
                    my Hash \dict = stream<dict>;
                    $stream-type = .value with dict<Type>;

                    # reset/repair stream length
                    dict<Length> = :int(stream<encoded>.codes)
                        if $repair;

		    if $stream-type ~~ 'XRef' {
			self!set-trailer( dict, :keys[<Root Encrypt Info ID>] );
			self!setup-crypt(|c);
			# discard existing /Type /XRef stream objects. These are specific to the input PDF
			next;
		    }
                }

                %!ind-obj-idx{"$obj-num $gen-num"} //= %(
                    :type(External),
                    :@ind-obj,
                    :$offset,
                );

                with $stream-type {
                    when 'ObjStm' {
                        # Object Stream. Index contents as type 2 objects
                        my \container-obj = $.ind-obj( $obj-num, $gen-num ).object;
                        my Array \embedded-objects = container-obj.decoded;
                        for embedded-objects.kv -> $index, $_ {
                            my UInt $sub-obj-num = .[0];
                            my UInt $ref-obj-num = $obj-num;
                            %!ind-obj-idx{"$sub-obj-num 0"} //= %(
                                :type(Embedded),
                                :$index,
                                :$ref-obj-num,
                            );
                        }
                    }
                }
            }

            with .<trailer> {
                my Hash \trailer = PDF::COS.coerce( |$_ );
                self!set-trailer( trailer.content<dict> );
		self!setup-crypt(|c);
            }
        }

        %ast;
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
        Bool :$incremental = False       #| only return updated objects
        ) {
        my @object-refs;
        my %objstm-objects;

        for %!ind-obj-idx.values {
            # implicitly an objstm object, if it contains type2 (embedded) objects
            %objstm-objects{ .<ref-obj-num> }++
                if .<type> == 2;
        }

        for %!ind-obj-idx.pairs.sort {
            my UInt ($obj-num, $gen-num) = .key.split(' ')>>.Int;

            # discard objstm objects (/Type /ObjStm)
            next with %objstm-objects{$obj-num};

            my Hash $entry = .value;
            my UInt $seq = 0;
            my UInt $offset;

            given $entry<type> {
                when External {
                    $offset = $_
                    with $entry<offset>
                }
                when Embedded {
                    my UInt $parent = $entry<ref-obj-num>;
		    with %!ind-obj-idx{"$parent 0"} {
                        $offset = .<offset>;
                    }
                    else {
			die "unable to find object: $parent 0 R"
                    }
                    $seq = $entry<index>;
                }
                when Free {
                    next;
                }
                default { die "unknown ind-obj index <type> $obj-num $gen-num: {.perl}" }
            }

	    my Bool $eager = ! $incremental;
            my \ast = $.ind-obj($obj-num, $gen-num, :get-ast, :$eager)
	        or next;

            if $incremental {
		if $offset && $obj-num {
		    # check updated vs original PDF value.
		    my \original-ast = self!fetch-ind-obj(%!ind-obj-idx{"$obj-num $gen-num"}, :$obj-num, :$gen-num);
		    # discard, if not updated
		    next if original-ast eqv ast.value;
		}
            }

            my \ind-obj = ast.value[2];

            with ind-obj<stream> {
                with .<dict><Type> -> \obj-type {
                    # discard existing /Type /XRef and ObjStm objects.
                    next if obj-type<name> ~~ 'XRef'|'ObjStm';
                }
            }

            $offset //= 0;
            @object-refs.push( ($offset + $seq) => ast );
        }

        # preserve input order
        my @objects = @object-refs.list.sort(*.key).map: *.value;

        @objects;
    }

    #| get just updated objects. return as objects
    method get-updates() {
        my List \raw-objects = $.get-objects( :incremental );
        raw-objects.list.map({
            my Int $obj-num = .value[0];
            my Int $gen-num = .value[1];
            $.ind-obj($obj-num, $gen-num).object;
        });
    }

    multi method recompress(Bool :$compress = True) {
        # locate and compress/uncompress stream objects

        for self.get-objects.list -> \obj {
            next unless obj.key eq 'ind-obj';
            my \ind-obj = obj.value[2];
            my \obj-type = ind-obj.key;

            if obj-type eq 'stream' {
                my \obj-dict = ind-obj.value<dict>;
                my Int \obj-num = obj.value[0];
                my Int \gen-num = obj.value[1];
                my Bool \is-compressed = obj-dict<Filter>:exists;
                next if $compress == is-compressed;
                # fully stantiate object and adjust compression
                my \object = self.ind-obj( obj-num, gen-num).object;
                $compress ?? .compress !! .uncompress with object;
            }
        }
    }

    method ast( Bool :$rebuild ) {
        my \serializer = PDF::IO::Serializer.new( :reader(self) );

        my Array $body = $rebuild
            ?? serializer.body( self.trailer )
            !! serializer.body( );

        .crypt-ast('body', $body, :mode<encrypt>)
            with self.crypt;

        :cos{
            :header{ :$.type, :$.version },
            :$body,
        }
    }

    #| dump to json
    multi method save-as( Str $output-path where m:i/'.json' $/, |c ) {
        my \ast = $.ast(|c);
        $output-path.IO.spurt( to-json( ast ) );
    }

    #| write to PDF/FDF
    multi method save-as( Str $output-path, |c ) is default {
        my $ast = $.ast(|c);
        my PDF::Writer $writer .= new: :$.input, :$ast;
	$output-path.IO.spurt: $writer.Blob;
    }

}
