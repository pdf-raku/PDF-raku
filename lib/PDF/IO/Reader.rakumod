use v6;

my sub substr($_, |c) {
    .can('byte-str') ?? .byte-str(|c) !! .substr(|c);
}

my sub synopsis($input) {
    my \desc = (
        $input.chars < 60
            ?? $input
            !! [~] $input.&substr(0, 32), ' ... ', $input.&substr(*-20)
    ).subst(/\n+/, ' ', :g);
    desc.raku;
}

class X::PDF is Exception { }

class X::PDF::BadJSON is X::PDF {
    has Str $.input-file is required;
    method message {"File doesn't contain a top-level 'cos' struct: $!input-file"}
}

class X::PDF::BadHeader is X::PDF {
    has Str $.preamble is required;
    method message {"Expected file header '%XXX-n.m', got: {$!preamble.&synopsis()}"}
}

class X::PDF::BadTrailer is X::PDF {
    has Str $.tail is required;
    method message {"Expected file trailer 'startxref ... \%\%EOF', got: {$!tail.&synopsis()}"}
}

class X::PDF::NoTrailer is X::PDF {
    method message {"PDF file trailer not found"}
}

class X::PDF::BadXRef is X::PDF {}

class X::PDF::BadXRef::Parse is X::PDF::BadXRef {
    has Str $.xref is required;
    method message {"Unable to parse index: {$!xref.&synopsis()}"}
}

class X::PDF::BadXRef::Entry is X::PDF::BadXRef {
    has $.details;
    method message {"Cross reference error: $.details. Please inform the author of the PDF and/or try opening this PDF with :repair"}
}

class X::PDF::BadXRef::Entry::Number is X::PDF::BadXRef::Entry {
    has UInt $.obj-num;
    has UInt $.gen-num;
    has UInt $.actual-obj-num;
    has UInt $.actual-gen-num;
    method details {
        "Index entry was: $!obj-num $!gen-num R. actual object: $!actual-obj-num $!actual-gen-num R"
    }
}

class X::PDF::BadXRef::Section is X::PDF::BadXRef {
    has UInt $.obj-count;
    has UInt $.entry-count;
    method message {"xref section size mismatch. Expected $!obj-count entries, got $!entry-count"}
}

class X::PDF::ParseError is X::PDF {
    has Str $.input is required;
    method message {"Unable to parse PDF document: {$!input.&synopsis()}"}
}

class X::PDF::BadIndirectObject is X::PDF {
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
        $.details = "Unable to parse indirect object: " ~ $.input.&synopsis();
        nextsame;
    }
}

class X::PDF::ObjStmObject::Parse is X::PDF {
    has Str $.input is required;
    has UInt $.obj-num;
    has UInt $.ref-obj-num;
    method message {
        "Error extracting embedded object $!obj-num 0 R from $!ref-obj-num 0 R; unable to parse object: " ~ $.input.&synopsis();
    }
}

class PDF::IO::Reader {

    use PDF::COS;
    use PDF::Grammar:ver<0.2.1+>;
    use PDF::Grammar::COS;
    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::IO;
    use PDF::IO::IndObj;
    use PDF::IO::Serializer;
    use PDF::COS :IndRef;
    use PDF::COS::Dict;
    use PDF::COS::Util :from-ast, :to-ast;
    use PDF::IO::Writer;
    use Hash::int;
    use JSON::Fast;
    subset ObjNumInt of UInt;
    subset GenNumInt of Int where 0..999;
    subset StreamAstNode of Pair:D where .key eq 'stream';

    has PDF::IO  $.input is rw;      #= raw PDF image (latin-1 encoding)
    has Str      $.file-name;
    has          %!ind-obj-idx is Hash::int; # keys are: $obj-num*1000 + $gen-num
    has Bool     $.auto-deref is rw = True;
    has Rat      $.version is rw;
    has Str      $.type is rw;       #= 'PDF', 'FDF', etc...
    has uint64   $.prev;             #= xref offset
    has uint     $.size is rw;       #= /Size entry in trailer dict ~ first free object number
    has uint64    @.xrefs = (0);     #= xref position for each revision in the file
    has $.crypt is rw;
    has Rat $.compat;        #= cross reference stream mode
    method compat is rw {
        Proxy.new: 
            FETCH => { $!compat // $!version // 1.4 },
            STORE => -> $, $!compat {}
        ;
    }
    has Lock $!lock .= new;

    my enum IndexType <Free External Embedded>;

    submethod TWEAK(PDF::COS::Dict :$trailer) {
        self!install-trailer($_) with $trailer;
    }

    method actions {
        state $actions //= PDF::Grammar::PDF::Actions.new: :lite;
    }

    method trailer is rw {
        Proxy.new(
            FETCH => {
                # vivify
                self!install-trailer(PDF::COS::Dict.new: :reader(self))
                    unless %!ind-obj-idx{0}:exists;
                self.ind-obj(0, 0).object;
            },
            STORE => -> $, \obj {
                self!install-trailer(obj);
            },
        );
    }

    method !install-trailer(PDF::COS::Dict $object) {
        %!ind-obj-idx{0} = do {
            my PDF::IO::IndObj $ind-obj .= new( :$object, :obj-num(0), :gen-num(0) );
            %( :type(IndexType::External), :$ind-obj );
        }
    }

    method !setup-crypt(Str :$password = '') {
        my Hash $doc = self.trailer;
        with $doc<Encrypt> -> \enc {
            $!crypt = PDF::COS.required('PDF::IO::Crypt::PDF').new( :$doc );
            $!crypt.authenticate( $password );
            my \enc-obj-num = enc.obj-num // -1;
            my \enc-gen-num = enc.gen-num // -1;

            for %!ind-obj-idx.kv -> $k, Hash:D $idx {
                my ObjNumInt $obj-num = $k div 1000
                    or next;
                my GenNumInt $gen-num = $k mod 1000;

                # skip the encryption dictionary, if it's an indirect object
                if $obj-num == enc-obj-num
                    && $gen-num == enc-gen-num {
                        $idx<encrypted> = False;
                }
                else {
                    # decrypt all objects that have already been loaded
                    with $idx<ind-obj> -> $ind-obj {
                        die "too late to setup encryption: $obj-num $gen-num R"
                            if $idx<type> != Free | External
                            || $ind-obj.isa(PDF::IO::IndObj);

                        $!crypt.crypt-ast( (:$ind-obj), :$obj-num, :$gen-num, :mode<decrypt> );
                    }
                }
            }

            # handle special case of not encrypting document meta-data
            unless enc<EncryptMetadata> // True {
                temp $.auto-deref = False;
                with $doc.deref($doc<Root>) -> $catalog {
                    with $catalog<Metadata> {
                        when IndRef {
                            my ObjNumInt $obj-num = .value[0];
                            my GenNumInt $gen-num = .value[1];
                            .<encrypted> = False
                                with %!ind-obj-idx{$obj-num * 1000 + $gen-num}
                        }
                    }
                }
            }
        }
    }

    #| [PDF 32000 Table 15] Entries in the file trailer dictionary
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
    multi method open( Str $!file-name where {!.isa(PDF::IO)}, |c) is hidden-from-backtrace {
        $.open( $!file-name.IO, |c );
    }

    #| deserialize a JSON dump
    multi method open(IO::Path $input-path  where .extension.lc eq 'json', |c ) is hidden-from-backtrace {
        my \ast = from-json( $input-path.IO.slurp );
        my \root = ast<cos> if ast.isa(Hash);
        die X::PDF::BadJSON.new( :input-file($input-path.absolute) )
            without root;
        $!type = root<header><type> // 'PDF';
        $!version = root<header><version> // 1.2;
        for root<body>.list {

            for .<objects>.list.reverse {
                with .<ind-obj> -> $ind-obj {
                    (my ObjNumInt $obj-num, my GenNumInt $gen-num) = $ind-obj.list;
                    my $k := $obj-num * 1000 + $gen-num;
                    %!ind-obj-idx{$k} = %(
                        :type(IndexType::External),
                        :$ind-obj,
                    ) unless %!ind-obj-idx{$k}:exists;
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
    method update-index( :@entries!, UInt :$!prev, UInt :$!size ) {
        @!xrefs.push: $!prev;

        for @entries -> Hash $entry {
            my ObjNumInt $obj-num = $entry<obj-num>
                or next;

            my GenNumInt $gen-num = $entry<gen-num>;
            my UInt $type = $entry<type>;
            my $k := $obj-num * 1000 + $gen-num;

            given $type {
                when IndexType::Free {
                    %!ind-obj-idx{$k}:delete;
                }
                when IndexType::External {
                    my $ind-obj = $entry<ind-obj>;
                    %!ind-obj-idx{$k} = %(
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

    multi method open($input!, |c) is hidden-from-backtrace {
        $!input .= COERCE: $input;
        $.load-header( );
        $.load-cos( $.type, |c );
    }

    #| load the data for a stream object. Cross check actual size versus expected /Length
    method !fetch-stream-data(@ind-obj,           #| primary object
                              $input,             #| associated input stream
                              UInt :$offset,      #| offset of the object in the input stream
                              UInt :$obj-len,     #| upper bound for the end of the stream
        )
    {
        my (ObjNumInt $obj-num, GenNumInt $gen-num, $obj-raw) = @ind-obj;

        $obj-raw.value<encoded> //= do {
            my UInt \from = $obj-raw.value<start>:delete;
            my UInt \length = $.deref( $obj-raw.value<dict><Length> )
                // die X::PDF::BadIndirectObject.new(:$obj-num, :$gen-num, :$offset,
                                                     :details("Stream mandatory /Length field is missing")
                                                    );

            with $obj-len {
                die X::PDF::BadIndirectObject.new(
                    :$obj-num, :$gen-num, :$offset,
                    :details("Stream dictionary entry /Length {length} overlaps with neighbouring objects (maximum size here is {$obj-len - from} bytes)"),
                ) if length > $_ - from;
            }

            # ensure stream is followed by an 'endstream' marker
            my Str \tail = $input.byte-str( $offset + from + length, 20 );

            if tail ~~ m{<PDF::Grammar::COS::stream-tail>} {
                warn X::PDF::BadIndirectObject.new(
                    :$obj-num, :$gen-num, :$offset,
                    :details("Ignoring {$/.from} bytes before 'endstream' marker")
                    ) if $/.from;
            }
            else {
                die X::PDF::BadIndirectObject.new(
                    :$obj-num, :$gen-num, :$offset,
                    :details("Unable to locate 'endstream' marker after consuming /Length {length} bytes")
                    );
            }

            length
                ?? $input.byte-str( $offset + from, length )
                !! '';
        };
    }

    #| follow the index. fetch either type-1, or type-2 objects:
    #| type-1: fetch as a top level object from the pdf
    #| type-2: dereference and extract from the containing object
    method !fetch-ind-obj(
        :$type!, :$ind-obj is copy,
        :$offset, :$end,                       # type-1
        :$index, :$ref-obj-num, :$encrypted = True,  # type-2
        :$obj-num,
        :$gen-num) {
        # stantiate the object
        my ObjNumInt $actual-obj-num;
        my GenNumInt $actual-gen-num;

        given $type {
            when IndexType::External {
                die X::PDF::BadXRef::Entry.new: :details("Invalid cross-reference offset $offset for $obj-num $gen-num R")
                    unless $offset > 0;
                my UInt $obj-len = do given $end - $offset {
                    when 0     { X::PDF::BadXRef::Entry.new: :details("Duplicate cross-reference destination (byte offset $offset) for $obj-num $gen-num R")}
                    when * < 0 { die X::PDF::BadXRef::Entry.new: :details("Attempt to fetch object $obj-num $gen-num R at byte offset $offset, past end of PDF ($end bytes)") }
                    default    { $_ }
                }

                my $input = $!input.byte-str( $offset, $obj-len );
                PDF::Grammar::COS.subparse( $input, :$.actions, :rule<ind-obj-nibble> )
                    or die X::PDF::BadIndirectObject::Parse.new( :$obj-num, :$gen-num, :$offset, :$input);

                $ind-obj = $/.ast.value;

                $actual-obj-num = $ind-obj[0];
                $actual-gen-num = $ind-obj[1];

                self!fetch-stream-data($ind-obj, $!input, :$offset, :$obj-len)
                    if $ind-obj[2] ~~ StreamAstNode;

                with $!crypt {
                    .crypt-ast( (:$ind-obj), :$obj-num, :$gen-num, :mode<decrypt> )
                        if $encrypted;
                }
            }
            when IndexType::Embedded {
                my subset ObjStm of Hash where { .<Type> ~~ 'ObjStm' }
                my ObjStm \container-obj = $.ind-obj( $ref-obj-num, 0 ).object;
                my \embedded-objects = container-obj.decoded;

                my Array \ind-obj-ref = embedded-objects[$index];
                $actual-obj-num = ind-obj-ref[0];
                $actual-gen-num = 0;
                my $input = ind-obj-ref[1];

                PDF::Grammar::COS.subparse( trim($input), :$.actions, :rule<object> )
                    or die X::PDF::ObjStmObject::Parse.new( :$obj-num, :$input, :$ref-obj-num);
                $ind-obj = [ $actual-obj-num, $actual-gen-num, $/.ast ];
            }
            default {die "unhandled index type: $_"};
        }

        die X::PDF::BadXRef::Entry::Number.new( :$obj-num, :$actual-obj-num, :$gen-num, :$actual-gen-num )
            unless $obj-num == $actual-obj-num && $gen-num == $actual-gen-num;

        $ind-obj;
    }

    #| fetch and stantiate indirect objects. cache against the index
    method ind-obj( ObjNumInt $obj-num!, GenNumInt $gen-num!,
                    Bool :$get-ast = False,  #| get ast data, not formulated objects
                    Bool :$eager = True,     #| fetch object, if not already loaded
        ) {

        my Hash $idx := %!ind-obj-idx{$obj-num * 1000 + $gen-num}
            // die "unable to find object: $obj-num $gen-num R";

        $!lock.protect: {
            my $ind-obj;
            my Bool $have-ast = True;    
            with $idx<ind-obj> {
                $ind-obj := $_;
                $have-ast := False
                    if $ind-obj.isa(PDF::IO::IndObj);
            }
            else {
                return unless $eager;
                $idx<ind-obj> = $ind-obj := self!fetch-ind-obj(|$idx, :$obj-num, :$gen-num);
            }

            if $get-ast {
                # AST requested.
                $have-ast ?? :$ind-obj !! $ind-obj.ast;
            }
            else {
                # Object requested.
                $have-ast
                    ?? ($idx<ind-obj> = PDF::IO::IndObj.new( :$ind-obj, :reader(self) ))
                    !! $ind-obj;
            }
        }
    }

    #| raw fetch of an object, without indexing or decryption
    method get(ObjNumInt $obj-num, GenNumInt $gen-num) {
        my %idx := %!ind-obj-idx{$obj-num * 1000 + $gen-num}
            // die "unable to find object: $obj-num $gen-num R";
         self!fetch-ind-obj(|%idx, :!encrypted, :$obj-num, :$gen-num);
    }

    #| utility method for basic deferencing, e.g.
    #| $reader.deref($root,<Pages>,<Kids>,[0],<Contents>)
    method deref($val is copy, **@ops ) is rw {
        for @ops -> \op {
            $val = self!ind-deref($val)
                if $val.isa(Pair);
            $val = do given op {
                when Str   { $val{ $_ } }
                when UInt  { $val[ $_ ] }
                when Array { $val[ .[0] ] }
                default    {die "bad \$.deref arg: {.raku}"}
            };
        }
        $val = self!ind-deref($val)
            if $val.isa(Pair);
        $val;
    }

    method !ind-deref(Pair $_! ) {
        return .value unless $_ ~~ IndRef;
        my ObjNumInt \obj-num = .value[0];
        my GenNumInt \gen-num = .value[1];
        $.ind-obj( obj-num, gen-num ).object;
    }

    method load-header() {
        # file should start with: %PDF-n.m, (where n, m are single
        # digits giving the major and minor version numbers).

        my Str $preamble = $!input.byte-str(0, 32);

        PDF::Grammar::COS.subparse($preamble, :$.actions, :rule<header>)
            or PDF::Grammar::COS.subparse($preamble ~ $!input.byte-str(32, 1024), :$.actions, :rule<header>)
            or die X::PDF::BadHeader.new( :$preamble );
        given $/.ast {
            $!version = .<version>;
            $!type = .<type>;
        }
    }

    #| Load input in FDF (Form Data Definition) format.
    #| Use full-scan mode, as these are not indexed.
    multi method load-cos('FDF') {
        self!full-scan(PDF::COS.required('PDF::Grammar::FDF'), $.actions);
    }

     #| Load a regular PDF file, repair or index mode
     multi method load-cos(
         'PDF',
         :$repair, #| scan the PDF, bypass any indices or stream lengths
         |c ) {
         $repair
             ?? self!full-scan( PDF::Grammar::PDF, $.actions, :repair, |c )
             !! self!load-index( PDF::Grammar::PDF, $.actions, |c );
     }

    multi method load-cos($type, |c) {
        self!load-index(PDF::Grammar::COS, $.actions, |c );
    }

    method !locate-xref($input-bytes, $tail-bytes, $tail, $offset is copy) {
        my str $xref;
        constant SIZE = 4096;       # big enough to usually contain xref

        if $offset >= $input-bytes - $tail-bytes {
            $xref = $!input.byte-str( $offset, $tail-bytes )
        }
        elsif $input-bytes - $tail-bytes - $offset <= SIZE {
            # xref abuts currently read $tail
            my UInt $adjacent-bytes = min(SIZE, $input-bytes - $tail-bytes - $offset);
            $xref = $!input.byte-str( $offset, $adjacent-bytes) ~ $tail;
        }
        else {
            # scan for '%%EOF' marker at the end of the trailer
            $xref = '';
            my $n = 0;
            repeat {
                my UInt $len = min(SIZE * ++$n, $input-bytes - $offset);
                $xref ~= $!input.byte-str( $offset, $len );
                $offset += $len;
            } until $xref ~~ /'%%EOF'/ || $offset >= $input-bytes;
        }
        $xref;
    }

    #| load PDF 1.4- xref table followed by trailer
    method !load-xref-table(Str $xref is copy, $dict is rw, :$offset) {
        my $parse = PDF::Grammar::COS.subparse( $xref, :rule<index>, :$.actions );
        die X::PDF::BadXRef::Parse.new( :$offset, :$xref )
            unless $parse;

        my \index = $parse.ast;

        $dict = PDF::COS.coerce( |index<trailer>, :reader(self) );

        index<xref>».<entries>;
    }

    #| load PDF 1.4- xref table followed by trailer
    #| experimental use of PDF::Native::Reader
    method !load-xref-table-fast(Str $xref is copy, $dict is rw, :$offset, :$fast-reader!) {
        # fast load of the xref segments
        my $buf = $xref.encode("latin-1");
        my array $entries = $fast-reader.read-xref($buf)
            // die X::PDF::BadXRef::Parse.new( :$offset, :$xref );
        my $bytes = $fast-reader.xref-bytes;

        # parse and load the trailer
        my $trailer = $buf.subbuf($bytes).decode("latin-1");
        my $parse = PDF::Grammar::COS.subparse( $trailer.trim, :rule<trailer>, :$.actions );
        die X::PDF::BadXRef::Parse.new( :$offset, :$xref )
            unless $parse;
        my \index = $parse.ast;
        $dict = PDF::COS.coerce( |index<trailer>, :reader(self) );

        my uint64 @seg[+$entries div 4;4] Z= @$entries;

        [@seg, ];
    }

    #| load a PDF 1.5+ XRef Stream
    method !load-xref-stream(Str $xref is copy, $dict is rw, UInt :$offset, :@discarded) {
        my $parse = PDF::Grammar::COS.subparse($xref, :$.actions, :rule<ind-obj>);

        die X::PDF::BadIndirectObject::Parse.new( :$offset, :input($xref))
            unless $parse;

        my %ast = $parse.ast;
        my PDF::IO::IndObj $ind-obj .= new( |%ast, :input($xref), :reader(self) );
        my subset XRefLike of Hash where { .<Type> ~~ 'XRef' }
        $dict = my XRefLike $ = $ind-obj.object;
        # we don't want to index these
        @discarded.push: $ind-obj.obj-num * 1000 + $ind-obj.gen-num;
        $dict.decode-index;
    }

    #| scan indices, starting at PDF tail. objects can be loaded on demand,
    #| via the $.ind-obj() method.
    method !load-index($grammar, $actions, |c) {
        my UInt \tail-bytes = min(1024, $!input.codes);
        my Str $tail = $!input.byte-str(* - tail-bytes);
        my UInt %offsets-seen;
        @!xrefs = [];

        $grammar.parse($tail, :$actions, :rule<postamble>)
            or do {
                CATCH { default {die X::PDF::BadTrailer.new( :$tail ); } }
                # unable to find 'startxref'
                # see if the PDF can be loaded sequentially
                return self!full-scan( $grammar, $actions, |c )
            }

        $!prev = $/.ast<startxref>;
        my UInt $offset = $!prev;
        my UInt \input-bytes = $!input.codes;
        my UInt @discarded;
        my Hash $dict;
        my UInt @ends;
        state $fast-reader = INIT try { (require ::('PDF::Native::Reader')).new }

        $!compat = $!version // 1.4;

        while $offset.defined {
            my array @obj-idx; # array of shaped arrays
            @!xrefs.unshift: $offset;
            die "xref '/Prev' cycle detected \@$offset"
                if %offsets-seen{$offset}++;
            # see if our cross reference table is already contained in the current tail
            my Str \xref = self!locate-xref(input-bytes, tail-bytes, $tail, $offset);
            if xref ~~ m:s/^ xref/ {
                # traditional 1.4 cross reference index
                @obj-idx.append: (
                $fast-reader.defined
                    ?? self!load-xref-table-fast( xref, $dict, :$offset, :$fast-reader)
                    !! self!load-xref-table( xref, $dict, :$offset));
                with $dict<XRefStm> {
                    # hybrid 1.4 / 1.5 with a cross-reference stream
                    # that contains additional objects
                    my $xref-dict = {};
                    my Str \xref-stm = self!locate-xref(input-bytes, tail-bytes, $tail, $_);
                    @obj-idx.push: self!load-xref-stream(xref-stm, $xref-dict, :offset($_), :@discarded);
                }
                $!compat = 1.4 if $!compat > 1.4;
            }
            else {
                # PDF 1.5+ cross reference stream.
                # need to write index in same format for Adobe reader (issue #22)
                @obj-idx.push: self!load-xref-stream(xref, $dict, :$offset, :@discarded);
                $!compat = 1.5 if $!compat < 1.5;
            }

            self!set-trailer: $dict;

            enum ( :ObjNum(0), :Type(1),
                   :Offset(2), :GenNum(3),     # Type 1 (External) Objects
                   :RefObjNum(2), :Index(3)    # Type 2 (Embedded) Objects
                 );

            for @obj-idx {
                for ^.elems -> $i {
                    my $type := .[$i;Type];

                    if $type == IndexType::Embedded {
                        my UInt      $index       := .[$i;Index];
                        my ObjNumInt $ref-obj-num := .[$i;RefObjNum];
                        my $k := .[$i;ObjNum] * 1000;
                        %!ind-obj-idx{$k} = %( :$type, :$index, :$ref-obj-num )
                            unless %!ind-obj-idx{$k}:exists;
                    }
                    elsif $type == IndexType::External {
                        my $k := .[$i;ObjNum] * 1000 + .[$i;GenNum];
                        my $offset = .[$i;Offset];
                        %!ind-obj-idx{$k} = %( :$type, :$offset )
                            unless %!ind-obj-idx{$k}:exists;
                        @ends.push: $offset;
                    }
                }
            }

            %!ind-obj-idx{$_}:delete for @discarded;
            $offset = do with $dict<Prev> { $_ } else { Int };
            $!size  = do with $dict<Size> { $_ } else { 1 };
        }

        #| don't entirely trust /Size entry in trailer dictionary
        my ObjNumInt \actual-size = max( %!ind-obj-idx.keys ) div 1000;
        $!size = actual-size + 1
            if $!size <= actual-size;

        # constrain indirect objects to a maximum end position
        @ends.append: @!xrefs;
        @ends.push: input-bytes;
        @ends .= sort;

        # mark end positions of external objects
        my int $i = 0;
        my int $n = +@ends - 1;
        for %!ind-obj-idx.values.grep(*<offset>).sort(*<offset>) {
            repeat {
                .<end> = @ends[$i];
                $i++ unless $i >= $n;
            } until .<end> > .<offset>;
            # cull, if freed
            %!ind-obj-idx{.<obj-num>*1000 + .<gen-num>}:delete
                unless .<type>;
        }

        self!setup-crypt(|c);
    }

    #| differentiate update xrefs from hybrid xrefs
    method revision-xrefs {
        my UInt @updates;
        for @!xrefs {
            @updates.push: $_
                if !@updates || $_ > @updates.tail;
        }
        @updates;
    }

    #| bypass any indices. directly parse and reconstruct index from objects.
    method !full-scan( $grammar, $actions, Bool :$repair, |c) {
        temp $actions.get-offsets = True;
        my Str $input = ~$!input;
        $grammar.parse($input, :$actions)
            or die X::PDF::ParseError.new( :$input );

        my %ast = $/.ast;
        my Hash @body = %ast<body>.list;

        for @body.reverse {
            my Pair @objects = .<objects>.list;

            for @objects.reverse {
                next unless .key eq 'ind-obj';
                my @ind-obj = .value.list;
                my (ObjNumInt $obj-num, GenNumInt $gen-num, $object, UInt $offset) = @ind-obj;

                my $stream-type;

                if $object ~~ StreamAstNode {
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

                my $k := $obj-num * 1000 + $gen-num;
                %!ind-obj-idx{$k} = %(
                    :type(IndexType::External),
                    :@ind-obj,
                    :$offset,
                ) unless %!ind-obj-idx{$k}:exists;

                with $stream-type {
                    when 'ObjStm' {
                        # Object Stream. Index contents as type 2 objects
                        my \container-obj = $.ind-obj( $obj-num, $gen-num ).object;
                        my Array \embedded-objects = container-obj.decoded;
                        for embedded-objects.kv -> $index, $_ {
                            my ObjNumInt $sub-obj-num = .[0];
                            my ObjNumInt $ref-obj-num = $obj-num;
                            my $k := $sub-obj-num * 1000;
                            %!ind-obj-idx{$k} = %(
                                :type(IndexType::Embedded),
                                :$index,
                                :$ref-obj-num,
                            ) unless %!ind-obj-idx{$k}:exists;
                        }
                    }
                }
            }

            with .<trailer> {
                my Hash \trailer = PDF::COS.coerce( |$_ );
                self!set-trailer( trailer.content<dict> );
                self!setup-crypt(|c);
            }
            else {
                die X::PDF::NoTrailer.new
                    unless self.trailer;
            }
        }

        %ast;
    }

    #| Get a list of indirect objects in the PDF
    #| - preserve input order
    #| - sift /XRef and /ObjStm objects,
    method get-objects(
        Bool :$incremental = False,     #| only return updated objects
        Bool :$eager = ! $incremental,  #| fetch uncached objects
        ) {
        my @object-refs;
        for %!ind-obj-idx.keys.sort {
            my Hash:D $entry = %!ind-obj-idx{$_};
            my ObjNumInt $obj-num = $_ div 1000;
            my GenNumInt $gen-num = $_ mod 1000;

            my UInt $seq = 0;
            my UInt $offset;

            given $entry<type> {
                when IndexType::External {
                    $offset = $_
                        with $entry<offset>
                }
                when IndexType::Embedded {
                    my UInt $parent = $entry<ref-obj-num>;
                    with %!ind-obj-idx{$parent * 1000} {
                        $offset = .<offset>;
                    }
                    else {
                        die "unable to find object: $parent 0 R"
                    }
                    $seq = $entry<index>;
                }
                when IndexType::Free {
                    next;
                }
                default {
                    die "unknown ind-obj index <type> $obj-num $gen-num: {.raku}"
                }
            }

            my \ast = $.ind-obj($obj-num, $gen-num, :get-ast, :$eager);

            with ast {
                my \ind-obj = .value[2];

                # discard existing /Type /XRef and ObjStm objects.
                with ind-obj<stream> {
                    with .<dict><Type> -> \obj-type {
                        next if obj-type<name> ~~ 'XRef'|'ObjStm';
                    }
                }
            }
            elsif $incremental {
                next;
            }

            if $incremental && $offset && $obj-num {
                # check updated vs original PDF value.
                my \original-ast = self!fetch-ind-obj(|%!ind-obj-idx{$obj-num * 1000 + $gen-num}, :$obj-num, :$gen-num);
                # discard, if not updated
                next if original-ast eqv ast.value;
            }

            $offset //= 0;
            @object-refs.push( ($offset + $seq) => (ast // :copy[$obj-num, $gen-num, self]) );
        }

        # preserve file order
        my @ = @object-refs.list.sort(*.key)».value;
    }

    #| get just updated objects. return as indirect objects
    method get-updates() {
        my List \raw-objects = $.get-objects( :incremental );
        raw-objects.map: {
            my ObjNumInt $obj-num = .value[0];
            my GenNumInt $gen-num = .value[1];
            $.ind-obj($obj-num, $gen-num).object;
        };
    }

    method recompress(Bool:D :$compress = True) {
        # locate and or compress/uncompress stream objects
        # replace deprecated LZW compression with Flate

        for self.get-objects
            .grep(*.key eq 'ind-obj')
            .map(*.value)
            .grep: {.[2] ~~ StreamAstNode} {

            my ObjNumInt \obj-num = .[0];
            my GenNumInt \gen-num = .[1];
            my \stream-dict = .[2].value<dict>;
            my Bool \is-compressed = stream-dict<Filter>:exists;

            next if $compress == is-compressed
            # always recompress LZW (which is deprecated)
            && !($compress && stream-dict<Filter><name> ~~ 'LZWDecode');

            # fully stantiate object and adjust compression
            my \object = self.ind-obj( obj-num, gen-num).object;
            $compress ?? .compress !! .uncompress with object;
        }
    }

    method ast(::CLASS:D $reader: Bool :$rebuild, |c ) {
        my PDF::IO::Serializer $serializer .= new: :$reader;

        my Array $body = $rebuild
            ?? $serializer.body( $reader.trailer, |c )
            !! $serializer.body( |c );

        .crypt-ast('body', $body, :mode<encrypt>)
            with $reader.crypt;
        :cos{
            :header{ :$.type, :$!version },
            :$body,
        }
    }

    #| dump to json
    multi method save-as( Str $output-path where m:i/'.json' $/, |c ) {
        my \ast = $.ast(|c);
        $output-path.IO.spurt( to-json( ast ) );
    }

    #| write to PDF/FDF
    multi method save-as(IO() $output-path, :$stream, |c ) {
        my $ast = $.ast(:!eager, |c);
        my PDF::IO::Writer $writer .= new: :$!input, :$ast, :$.compat;
        if $stream {
            my $ioh = $output-path.open(:w, :bin);
            $writer.stream-cos: $ioh, $ast<cos>;
            $ioh.close;
        }
        else {
            $output-path.spurt: $writer.Blob;
        }
        $writer;
    }

}
