use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Hash
    does PDF::Reader::Tied {

    method AT-KEY($key!) {
        $.reader
            ?? $.tied( callsame )
            !! callsame
    }

}
