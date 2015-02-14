use v6;

use PDF::Tools::IndObj::Stream;

# /Type /XRef - cross reference stream
# introduced with PDF 1.5
our class PDF::Tools::IndObj::XRef
    is PDF::Tools::IndObj::Stream {

    use PDF::Tools::Util :resample, :unbox;

    method W is rw { %.dict<W>; }
    method Size is rw { %.dict<Size>; }

    method !setup-dict(Array $xref) {
        $.Size = :int( +$xref );
        $.W //= :array[ :int(1), :int(2), :int(1) ];
        # resize byte-widths, if needed
        for 0..2 -> $i {
            my $val = $xref.map({ .[$i] }).max;
            
            my $max-bytes;

            repeat {
                $max-bytes++;
                $val div= 256;
            } until $val == 0;

            $.W.value[$i] = :int($max-bytes)
                if ! $.W.value[$i].defined || $.W.value[$i].value < $max-bytes;
        }
    }

    multi submethod BUILD( :$decoded!) {
        self!"setup-dict"($decoded);        
    }

    method encode(Array $xref = $.decoded --> Str) {
        self!"setup-dict"($xref);
        my $str = resample( $xref, unbox($.W), 8 ).chrs;
        nextwith( $str );
    }

    method decode($? --> Array) {
        my $chars = callsame;
        my $W = $.W
            // die "missing mandatory /XRef param: /W";
        resample( $chars.encode('latin-1'), 8, unbox ( $W ) );
    }
}

