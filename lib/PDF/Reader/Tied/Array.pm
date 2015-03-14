use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Array
    does PDF::Reader::Tied {

    method AT-POS(|c) {
        $.reader
            ?? $.tied( callsame )
            !! nextsame;
    }

    method ASSIGN-POS(|c) {
        $.changed = True;
        nextsame;
    }

    method BIND-POS(|c) {
        $.changed = True;
        nextsame;
    }

    method DELETE-POS(|c) {
        $.changed = True;
        nextsame;
    }

 }
