use v6;

use PDF::Basic::Filter;

class PDF::Basic::IndObj::Stream {

    has %.dict;
    has $.encoded;
    has $.decoded;

    method encoded {
        $!encoded //= $.encode( $!decoded )
            if $!decoded.defined;
        $!encoded;
    }

    method decoded {
        $!decoded //= $.decode( $!encoded )
            if $!encoded.defined;
        $!decoded;
    }

    method Filter is rw {
        %.dict<Filter>;
    }

    method DecodeParams is rw {
        %.dict<DecodeParams>;
    }

    method Type is rw {
        %.dict<Type>;
    }

    method decode( $input ) {
        PDF::Basic::Filter.decode( $input, :$.dict );
    }

    method encode( $input ) {
        PDF::Basic::Filter.encode( $input, :$.dict );
    }
}
