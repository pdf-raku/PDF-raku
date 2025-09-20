use v6;

#| Stream - base class for specific stream objects, e.g. Type::ObjStm, Type::XRef, ...
unit class PDF::COS::Stream ;
use PDF::COS::Dict;
also is PDF::COS::Dict;

use PDF::COS::Tie;
use PDF::COS::Name;
use PDF::IO::Filter;
use PDF::COS::Util :from-ast, :ast-coerce;

##    use ISO_32000::Table_5-Entries_common_to_all_stream_dictionaries;
##    also does ISO_32000::Table_5-Entries_common_to_all_stream_dictionaries;

has UInt $.Length is entry;                       #| (Required) The number of bytes from the beginning of the line following the keyword stream to the last byte just before the keyword endstream

has PDF::COS::Name @.Filter is entry(:array-or-item);  #| (Optional) The name of a filter to be applied in processing the stream data found between the keywords stream and endstream, or an array of such names

has Hash @.DecodeParms is entry(:array-or-item);  #| (Optional) A parameter dictionary or an array of such dictionaries, used by the filters specified by Filter

my subset StrOrDict where Str|Hash;
has StrOrDict $.F is entry;                       #| (Optional; PDF 1.2) The file containing the stream data. If this entry is present, the bytes between stream and endstream are ignored
has PDF::COS::Name @.FFilter is entry(:array-or-item);       #| (Optional; PDF 1.2) The name of a filter to be applied in processing the data found in the stream’s external file, or an array of such names
has Hash @.FDecodeParms is entry(:array-or-item); #| (Optional; PDF 1.2) A parameter dictionary, or an array of such dictionaries, used by the filters specified by FFilter.

has UInt $.DL is entry;                           #| (Optional; PDF 1.5) A non-negative integer representing the number of bytes in the decoded (defiltered) stream.

has $.encoded;
has $.decoded;

submethod TWEAK(:$dict!) {
    with $!encoded {
        self<Length> = .codes
            unless $dict<Length>:exists;
    }
}

method encoded is rw {
    sub FETCH($) {
        $!encoded //= self.encode( $_ )
            with $!decoded;
        self<Length> //= .codes with $!encoded;
        $!encoded;
    }

    sub STORE($, $stream) {
        $!decoded = Any;
        self<Length> = .codes with $stream;
        $!encoded = $stream;
    }

    Proxy.new: :&FETCH, :&STORE;
}

method decoded is rw {
    sub FETCH($) {
        $!decoded //= self.decode( $_ )
            with $!encoded;
        $!decoded;
    }
    sub STORE($, $stream) {
        $!encoded = Any;
        self<Length>:delete;
        $!decoded = $stream;
    }
    Proxy.new: :&FETCH, :&STORE;
}

method edit-stream( Str :$prepend = '', Str :$append = '' ) {
    for $prepend, $append {
        if /<- [\x0..\xFF \n]>/ {
           die "illegal non-latin hex byte in stream-edit: {$/.Str.uniname} U+" ~ (~$/).ord.base(16)
        }
    }
    $.decoded = $prepend ~ ($!decoded // '') ~ $append;
}

method decode(PDF::COS::Stream:D $dict: $encoded = $.encoded ) {
    return $encoded unless $dict<Filter>:exists;
    PDF::IO::Filter.decode( $encoded, :$dict );
}

method encode(PDF::COS::Stream:D $dict: $decoded = $.decoded) {
    return $decoded unless $dict<Filter>:exists;
    PDF::IO::Filter.encode( $decoded, :$dict );
}

method content {
    my \encoded = $.encoded; # may update $.dict<Length>
    my Pair $dict = ast-coerce self;
    with encoded {
        stream => %( $dict, :encoded(.Str) );
    }
    else {
        $dict;   # no content - downgrade to dict
    }
}

method uncompress {
    my Bool $uncompressed;
    with self<Filter> {
        CATCH { when X::NYI {} }
        $.decoded();
        $uncompressed = True;
    }

    if $uncompressed {
        $!encoded = Nil;
        self<Filter>:delete;
        self<DecodeParms>:delete;
        self<Length> = $!decoded.codes;
        $!decoded;
    }
}

method compress {
    # reencode deprecated LZW as Flate
    self.uncompress
        if self<Filter>.first: 'LZWDecode';

    self<Filter> //= do {
        $!decoded //= $!encoded;
        $!encoded = Nil;
        self<Length>:delete;        # recompute this later
        PDF::COS::Name.COERCE('FlateDecode' );
    }
}

multi method gist(::?CLASS:D:) {
    callsame() ~ "\n" ~ self.encoded.Str.raku
}

multi method COERCE(Associative $_ where {.<dict>|.<encoded>|.<decoded>}, |c) {
    my $class := PDF::COS.load-dict: .<dict>//{}, :base-class(self.WHAT);
    $class.new: |$_, |c;
}
multi method COERCE(Associative $dict, |c) is DEPRECATED('COERCE({:$dict, :$encoded, :$decoded})') {
    my $class := PDF::COS.load-dict: $dict, :base-class(self.WHAT);
    $class.new: :$dict, |c;
}
