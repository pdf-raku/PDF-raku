use v6;

use PDF::DAO::Dict;

#| Stream - base class for specific stream objects, e.g. Type::ObjStm, Type::XRef, ...
class PDF::DAO::Stream
    is PDF::DAO::Dict {

    use PDF::DAO::Tie;
    use PDF::IO::Filter;
    use PDF::DAO::Util :from-ast, :to-ast-native;

    # see [PDF 1.7 TABLE 5 Entries common to all stream dictionaries]

    has UInt $.Length is entry;                     #| (Required) The number of bytes from the beginning of the line following the keyword stream to the last byte just before the keyword endstream

    my subset StrOrArray of Any where Str|Array;

    has StrOrArray $.Filter is entry;               #| (Optional) The name of a filter to be applied in processing the stream data found between the keywords stream and endstream, or an array of such names

    my subset DictOrArray of Any where Hash|Array;
    has DictOrArray $.DecodeParms is entry;         #| (Optional) A parameter dictionary or an array of such dictionaries, used by the filters specified by Filter

    has Str $.F is entry;                           #| (Optional; PDF 1.2) The file containing the stream data. If this entry is present, the bytes between stream and endstream are ignored
    has StrOrArray $.FFilter is entry;              #| (Optional; PDF 1.2) The name of a filter to be applied in processing the data found in the stream’s external file, or an array of such names
    has DictOrArray $.FDecodeParms is entry;        #| (Optional; PDF 1.2) A parameter dictionary, or an array of such dictionaries, used by the filters specified by FFilter.

    has UInt $.DL is entry;                         #| (Optional; PDF 1.5) A non-negative integer representing the number of bytes in the decoded (defiltered) stream.

    has $.encoded;
    has $.decoded;
    submethod TWEAK {
        self<Length> = .codes with $!encoded;
    }

    method encoded is rw {
	Proxy.new(
	    FETCH => sub ($) {
		$!encoded //= self.encode( $_ )
		    with $!decoded;

		self<Length> = .codes with $!encoded;
		$!encoded;
	    },

	    STORE => sub ($, $stream) {
		$!decoded = Any;
		self<Length> = .codes with $stream;
		$!encoded = $stream;
	    },
	    )
    }

    method decoded is rw {
	Proxy.new(
	    FETCH => sub ($) {
		$!decoded //= self.decode( $_ )
		    with $!encoded;
		$!decoded;
	    },
	    STORE => sub ($, $stream) {
		$!encoded = Any;
		self<Length>:delete;
		$!decoded = $stream;
	    }
	    );
    }

    method edit-stream( Str :$prepend = '', Str :$append = '' ) {
        for $prepend, $append {
            if /<- [\x0 .. \xFF]>/ {
               die "illegal non-latin hex byte in stream-edit: U+" ~ (~$/).ord.base(16)
            }
        }
        $.decoded = $prepend ~ ($!decoded // '') ~ $append;
    }

    method decode( $encoded = $.encoded ) {
        return $encoded unless self<Filter>:exists;
        PDF::IO::Filter.decode( $encoded, :dict(self) );
    }

    method encode( $decoded = $.decoded) {
        return $decoded unless self<Filter>:exists;
        PDF::IO::Filter.encode( $decoded, :dict(self) );
    }

    method content {
        my \encoded = $.encoded; # may update $.dict<Length>
        my Pair $dict = to-ast-native self;
	with encoded {
	    stream => %( $dict, :encoded(.Str) );
	}
	else {
	    $dict;   # no content - downgrade to dict
	}
    }

    method uncompress {
        if self<Filter>:exists {
            if try { $.decoded(); True } {
                $!encoded = Nil;
                self<Filter>:delete;
                self<DecodeParms>:delete;
                self<Length> = $!decoded.codes;
            }
        }
    }

    method compress {
        unless self<Filter>:exists {
            $!decoded //= $!encoded;
            $!encoded = Nil;
            self<Filter> = PDF::DAO.coerce( :name<FlateDecode> );
            self<Length>:delete;        # recompute this later
        }
    }

}
