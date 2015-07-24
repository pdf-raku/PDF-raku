use v6;

use PDF::Object;
use PDF::Object::Type;
use PDF::Object::Tie::Hash;

#| Stream - base class for specific stream objects, e.g. Type::ObjStm, Type::XRef, ...
class PDF::Object::Stream
    is PDF::Object
    is Hash
    does PDF::Object::Type 
    does PDF::Object::Tie::Hash {

    use PDF::Object::Tie;
    use PDF::Storage::Filter;
    use PDF::Object::Util :from-ast, :to-ast-native;

    has $!encoded;
    has $!decoded;

    has Str $!Filter is entry;
    has Hash $!DecodeParms is entry;
    has Int $!Length is entry;

    our %obj-cache = (); #= to catch circular references

    method new(Hash :$dict = {}, *%etc) {
        my Str $id = ~$dict.WHICH;
        my $obj = %obj-cache{$id};
        unless $obj.defined {
	    my %entries = PDF::Object::Tie.compose(self.WHAT);
            temp %obj-cache{$id} = $obj = self.bless(|%etc);
            # this may trigger cascading PDF::Object::Tie coercians
            # e.g. native Array to PDF::Object::Array
	    $obj.entries = %entries;
            $obj{.key} = from-ast(.value) for $dict.pairs;
            $obj.?cb-setup-type($obj);
        }
        $obj;
    }

    multi submethod BUILD( :$start!, :$end!, :$input!) {
        my Int $length = $end - $start + 1;
        $!encoded = $input.substr($start, $length );
    }

    multi submethod BUILD( :$!decoded!) {
    }

    multi submethod BUILD( :$!encoded!) {
    }

    multi submethod BUILD() is default {
    }

    multi method encoded(Str $stream!) {
        $!decoded = Any;
        self<Length> = $stream.chars;
        $!encoded = $stream;
    }

    multi method encoded is default {
        if $!decoded.defined {
            $!encoded //= $.encode( $!decoded );
        }
        self<Length> = $!encoded.chars;
        $!encoded;
    }

    multi method decoded(Str $stream!) {
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
        $!decoded //= '';
        $!decoded = $prepend ~ $!decoded ~ $append;
    }

    method decode( Str $encoded = $.encoded ) {
        return $encoded unless self<Filter>:exists;
        PDF::Storage::Filter.decode( $encoded, :dict(self) );
    }

    method encode( Str $decoded = $.decoded) {
        return $decoded unless self<Filter>:exists;
        PDF::Storage::Filter.encode( $decoded, :dict(self) );
    }

    method content {
        my $encoded = $.encoded; # may update $.dict<Length>
        my $dict = to-ast-native self;
        :stream( %( $dict, :$encoded ));
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
            require PDF::Object;
            self<Filter> = PDF::Object.compose( :name<FlateDecode> );
            self<Length>:delete;        # recompute this later
        }
    }

}
