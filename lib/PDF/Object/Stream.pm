use v6;

use PDF::Tools::Filter;
use PDF::Object ;
use PDF::Object::Type;
use PDF::Tools::Util :unbox;

#| Stream - base class for specific stream objects, e.g. Type::ObjStm, Type::XRef, ...
our class PDF::Object::Stream
    is PDF::Object
    does PDF::Object::Type {

    has Hash $.dict = {};
    has $!encoded;
    has $!decoded;

    method Filter is rw { %.dict<Filter> }
    method DecodeParms is rw { %.dict<DecodeParms> }
    method Length is rw { %.dict<Length> }

    multi submethod BUILD( :$!dict is copy = {}, :$start!, :$end!, :$input!) {
        my $length = $end - $start + 1;
        $!encoded = $input.substr($start, $length );
        $!dict<Length> = :int($length);
        self.setup-type( $!dict ); 
    }

    multi submethod BUILD( :$!dict is copy = {}, :$!decoded!) {
        self.setup-type( $!dict ); 
    }

    multi submethod BUILD( :$!dict! is copy, :$!encoded!) {
        $!dict<Length> = :int($!encoded.chars);
        self.setup-type( $!dict ); 
    }

    method encoded {
        if $!decoded.defined && ! $!encoded.defined {
            $!encoded = $.encode( $!decoded );
            $!dict<Length> = :int($!encoded.chars);
        }
        $!encoded;
    }

    method decoded {
        $!decoded //= $.decode( $!encoded )
            if $!encoded.defined;

        $!decoded;
    }

    method decode( Str $encoded = $.encoded ) {
        my $dict = unbox( :$.dict, :keys<Filter DecodeParms> );
        return $encoded unless $dict<Filter>:exists;
        PDF::Tools::Filter.decode( $encoded, :$dict );
    }

    method encode( Str $decoded = $.decoded) {
        my $dict = unbox( :$.dict, :keys<Filter DecodeParms> );
        return $decoded unless $dict<Filter>:exists;
        PDF::Tools::Filter.encode( $decoded, :$dict );
    }

    method content {
        :stream{ :$.dict, :$.encoded };
    }
}
