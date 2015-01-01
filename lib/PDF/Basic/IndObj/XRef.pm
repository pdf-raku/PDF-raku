use v6;

use PDF::Basic::IndObj::Stream;

# /Type /XRef - cross reference stream
# introduced with PDF 1.5
class PDF::Basic::IndObj::XRef
    is PDF::Basic::IndObj::Stream;

method W is rw {
    %.dict<W>;
}

use PDF::Basic::Util :resample;

method encode($xref = $.decoded --> Str) {
    $.W //= [1, 2, 1]; 
    my $str = resample( $xref, $.W, 8 ).chrs;
    nextwith( $str );
}

method decode($? --> Array) {
    my $chars = callsame;
    my $W = $.W
        // die "missing mandatory /XRef param: /W";
    resample( $chars.encode('latin-1'), 8, $W );
}

