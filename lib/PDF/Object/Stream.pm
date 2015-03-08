use v6;

use PDF::Tools::Filter;
use PDF::Object :box-native;
use PDF::Object::Dict;

#| Stream - base class for specific stream objects, e.g. Type::ObjStm, Type::XRef, ...
class PDF::Object::Stream
    is PDF::Object::Dict {

    has $!encoded;
    has $!decoded;

    method Filter is rw { self<Filter> }
    method DecodeParms is rw { self<DecodeParms> }
    method Length is rw { self<Length> }

    multi submethod BUILD( :$start!, :$end!, :$input!) {
        my $length = $end - $start + 1;
        $!encoded = $input.substr($start, $length );
    }

    multi submethod BUILD( :$!decoded!) {
    }

    multi submethod BUILD( :$!encoded!) {
    }

    method encoded {
        if $!decoded.defined && ! $!encoded.defined {
            $!encoded = $.encode( $!decoded );
        }
        self<Length> = $!encoded.chars;
        $!encoded;
    }

    method decoded {
        $!decoded //= $.decode( $!encoded )
            if $!encoded.defined;

        $!decoded;
    }

    method decode( Str $encoded = $.encoded ) {
        return $encoded unless self<Filter>:exists;
        PDF::Tools::Filter.decode( $encoded, :dict(self) );
    }

    method encode( Str $decoded = $.decoded) {
        return $decoded unless self<Filter>:exists;
        PDF::Tools::Filter.encode( $decoded, :dict(self) );
    }

    method content {
        my $encoded = $.encoded; # may update $.dict<Length>
        my $dict = box-native self;
        :stream( %( $dict, :$encoded ));
    }
}
