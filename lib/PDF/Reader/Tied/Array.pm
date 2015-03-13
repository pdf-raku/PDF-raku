use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Array
    does PDF::Reader::Tied {

    method AT-POS(*@arg) {
        $.reader
            ?? $.tied( callsame )
            !! callsame;
    }

 }
