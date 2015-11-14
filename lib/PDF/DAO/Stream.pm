use v6;

use PDF::DAO;
use PDF::DAO::Type;
use PDF::DAO::Tie::Hash;

#| Stream - base class for specific stream objects, e.g. Type::ObjStm, Type::XRef, ...
class PDF::DAO::Stream
    is PDF::DAO
    is Hash
    does PDF::DAO::Type 
    does PDF::DAO::Tie::Hash {

    use PDF::DAO::Tie;
    use PDF::Storage::Filter;
    use PDF::DAO::Util :from-ast, :to-ast-native;

    has $!encoded;
    has $!decoded;

    # see [PDF 1.7 TABLE 3.4 Entries common to all stream dictionaries]

    has UInt $.Length is entry;                     #| (Required) The number of bytes from the beginning of the line following the keyword stream to the last byte just before the keyword endstream

    my subset StrOrArray of Any where Str|Array;

    has StrOrArray $.Filter is entry;               #| (Optional) The name of a filter to be applied in processing the stream data found between the keywords stream and endstream, or an array of such names

    my subset DictOrArray of Any where Hash|Array;
    has DictOrArray $.DecodeParms is entry;         #| (Optional) A parameter dictionary or an array of such dictionaries, used by the filters specified by Filter

    has Str $.F is entry;                           #| (Optional; PDF 1.2) The file containing the stream data. If this entry is present, the bytes between stream and endstream are ignored
    has StrOrArray $.FFilter is entry;              #| (Optional; PDF 1.2) The name of a filter to be applied in processing the data found in the stream’s external file, or an array of such names
    has DictOrArray $.FDecodeParms is entry;        #| (Optional; PDF 1.2) A parameter dictionary, or an array of such dictionaries, used by the filters specified by FFilter.

    has UInt $.DL is entry;                         #| (Optional; PDF 1.5) A non-negative integer representing the number of bytes in the decoded (defiltered) stream.

    our %obj-cache = (); #= to catch circular references

    multi method new(Hash $dict!, |c) {
	self.new( :$dict, |c );
    }

    multi method new(Hash :$dict = {}, Int :$obj-num, Int :$gen-num, :$reader, :$decoded, :$encoded, |c) {
        my Str $id = ~$dict.WHICH;
        my $obj = %obj-cache{$id};
        unless $obj.defined {
            temp %obj-cache{$id} = $obj = self.bless(|c);
	    $obj.tie-init;
            # this may trigger cascading PDF::DAO::Tie coercians
            $obj{.key} = from-ast(.value) for $dict.pairs;
            $obj.?cb-init;

	    if my $required = set $obj.entries.pairs.grep({.value.tied.is-required}).map({.key}) {
		my $missing = $required (-) $obj.keys;
		die "{self.WHAT.^name}: missing required field(s): $missing"
		    if $missing;
	    }
        }
	if $decoded.defined {
	    $obj.decoded($decoded);
	}
	elsif $encoded.defined {
	    $obj.encoded($encoded);
	}
	$obj.obj-num = $obj-num if $obj-num.defined;
	$obj.gen-num = $gen-num if $gen-num.defined;
	$obj.reader  = $reader  if $reader.defined;
        $obj;
    }

    multi method encoded($stream!) {
        $!decoded = Any;
        self<Length> = $stream.codes
	    if $stream.can('codes');
        $!encoded = $stream;
    }

    multi method encoded is default {
        if $!decoded.defined {
            $!encoded //= $.encode( $!decoded );
        }

	if $!encoded.can('codes') {
	    self<Length> = $!encoded.codes;
	}
	else {
	    self<Length>:delete
	}
	$!encoded;
    }

    multi method decoded($stream!) {
        $!encoded = Any;
        self<Length>:delete;
        $!decoded = $stream;
    }

    multi method decoded is default {
        $!decoded //= $.decode( $!encoded )
            if $!encoded.defined;

        $!decoded;
    }

    method edit-stream( Str :$prepend = '', Str :$append = '' ) {
        for $prepend, $append {
            for .comb {
                die "illegal non-latin hex byte: U+" ~ .ord.base(16)
                    unless 0 <= .ord <= 0xFF;
            }
        }
        $.decoded;
        $!encoded = Any;
        $!decoded = $prepend ~ ($!decoded // '') ~ $append;
    }

    method decode( $encoded = $.encoded ) {
        return $encoded unless self<Filter>:exists;
        PDF::Storage::Filter.decode( $encoded, :dict(self) );
    }

    method encode( $decoded = $.decoded) {
        return $decoded unless self<Filter>:exists;
        PDF::Storage::Filter.encode( $decoded, :dict(self) );
    }

    method content {
        my $encoded = $.encoded; # may update $.dict<Length>
        my $dict = to-ast-native self;
	$encoded.defined
	    ?? :stream( %( $dict, :$encoded ))
	    !! $dict;   # no content - downgrade to dict
    }

    method uncompress {
        if self<Filter>:exists {
            if try { $.decoded(); True } {
                $!encoded = Nil;
                self<Filter>:delete;
                self<DecodeParms>:delete;
                self<Length> = $!decoded.chars;
            }
        }
    }

    method compress {
        unless self<Filter>:exists {
            $!decoded //= $!encoded;
            $!encoded = Nil;
            require PDF::DAO;
            self<Filter> = PDF::DAO.coerce( :name<FlateDecode> );
            self<Length>:delete;        # recompute this later
        }
    }

}
