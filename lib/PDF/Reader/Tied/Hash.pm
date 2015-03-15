use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Hash
    does PDF::Reader::Tied {

    method AT-KEY(|c) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref($result )
            !! $result;
    }

}
