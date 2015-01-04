use v6;

use PDF::Core::IndObj::Stream;
use PDF::Core::Util :unbox;

# /Type /XRef - cross reference stream
# introduced with PDF 1.5
our class PDF::Core::IndObj::XRef
    is PDF::Core::IndObj::Stream;

method W is rw {
    %.dict<W>;
}

use PDF::Core::Util :resample;

method encode($xref = $.decoded --> Str) {
    $.W //= :array[ :int(1), :int(2), :int(1) ];
    my $str = resample( $xref, unbox($.W), 8 ).chrs;
    nextwith( $str );
}

method decode($? --> Array) {
    my $chars = callsame;
    my $W = $.W
        // die "missing mandatory /XRef param: /W";
    resample( $chars.encode('latin-1'), 8, unbox ( $W ) );
}

