use v6;

use PDF::Basic::IndObj::Stream;

# /Type /XRef - cross reference stream
# introduced with PDF 1.5
class PDF::Basic::IndObj::XRef
    is PDF::Basic::IndObj::Stream;

use PDF::Basic::Util :resample;

method encode(Array $xref, :$dict --> Str) {
    my $W = $dict<W>
        // die "missing mandatory /XRef param: /W";
    my $str = resample( $xref, $W, 8 ).chrs;
    nextwith( $str, :$dict);
}

method decode(Str $, :$dict --> Array) {
    my $chars = callsame;
    my $W = $dict<W>
        // die "missing mandatory /XRef param: /W";
    resample( $chars.encode('latin-1'), 8, $W );
}

