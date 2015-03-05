use v6;

use PDF::Tools::Filter;
use PDF::Object :box;
use PDF::Object::Type;

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
        $!dict<Length> = $length;
        self.setup-type( $!dict ); 
    }

    multi submethod BUILD( :$!dict is copy = {}, :$!decoded!) {
        self.setup-type( $!dict ); 
    }

    multi submethod BUILD( :$!dict is copy = {}, :$!encoded!) {
        $!dict<Length> = $!encoded.chars;
        self.setup-type( $!dict ); 
    }

    method encoded {
        if $!decoded.defined && ! $!encoded.defined {
            $!encoded = $.encode( $!decoded );
            $!dict<Length> = $!encoded.chars;
        }
        $!encoded;
    }

    method decoded {
        $!decoded //= $.decode( $!encoded )
            if $!encoded.defined;

        $!decoded;
    }

    method decode( Str $encoded = $.encoded ) {
        return $encoded unless $.dict<Filter>:exists;
        PDF::Tools::Filter.decode( $encoded, :$.dict );
    }

    method encode( Str $decoded = $.decoded) {
        return $decoded unless $.dict<Filter>:exists;
        PDF::Tools::Filter.encode( $decoded, :$.dict );
    }

    method content {
        my $encoded = $.encoded; # may update $.dict<Length>
        my $dict = box $.dict;
        :stream( %( $dict, :$encoded ));
    }
}
