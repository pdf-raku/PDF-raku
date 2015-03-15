use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Array
    does PDF::Reader::Tied {

    method AT-POS(|c) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref($result )
            !! $result;
    }

 }
