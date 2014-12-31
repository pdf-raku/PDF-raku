use v6;

use PDF::Basic::Filter;

#| Stream - base class for specific indirect objects, e.g. ObjStm, XRef, ...
class PDF::Basic::IndObj::Stream {

    has $.dict;
    has $.encoded;
    has $.decoded;

    multi submethod BUILD( :$!dict!, :$start!, :$end!, :$input!) {
        my $length = $end - $start + 1;
        $!encoded = $input.substr($start - 1, $length - 1 );
    }

    multi submethod BUILD( :$!dict!, :$!decoded, :$!encoded ) {
    }

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

    method DecodeParms is rw {
        %.dict<DecodeParms>;
    }

    method Type is rw {
        %.dict<Type>;
    }

    method decode( $encoded = $.encoded ) {
        PDF::Basic::Filter.decode( $encoded, :$.dict );
    }

    method encode( $decoded = $.decoded) {
        PDF::Basic::Filter.encode( $decoded, :$.dict );
    }
}
