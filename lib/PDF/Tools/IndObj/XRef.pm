use v6;

use PDF::Tools::IndObj::Stream;

# /Type /XRef - cross reference stream
# introduced with PDF 1.5
our class PDF::Tools::IndObj::XRef
    is PDF::Tools::IndObj::Stream {

    use PDF::Tools::Util :resample, :unbox;

    # See [PDF 1.7 Table 3.15]
    method W is rw { %.dict<W>; }
    method Size is rw { %.dict<Size>; }
    method Index is rw { %.dict<Index> }
    method first-obj-num is rw { %.dict<Index>.value[0].value }
    method next-obj-num is rw { %.dict<Size>.value }

    multi submethod BUILD( :$dict, :$decoded!) {
        self!"setup-dict"($decoded);
    }

    method !setup-dict(Array $xref, $dict?) {
        $.dict = $dict if $dict.defined;
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

        $.Index //= :array[ :int(0) ];
        $.Index.value[1] = :int(+$xref);
        $.Size //= :int(0);
    }

    method encode(Array $xref = $.decoded --> Str) {
        self!"setup-dict"($xref);

        die 'mandatory /Index[0] entry is missing or zero'
            unless $.first-obj-num;

        die 'mandatory /Size entry is missing or zero'
            unless $.next-obj-num;

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

