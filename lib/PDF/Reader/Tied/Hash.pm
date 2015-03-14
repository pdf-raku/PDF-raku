use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Hash
    does PDF::Reader::Tied {

    method AT-KEY(|c) {
        $.reader
            ?? $.tied( callsame )
            !! nextsame
    }

    method ASSIGN-KEY(|c) {
        $.changed = True;
        nextsame;
    }

    method BIND-KEY(|c) {
        $.changed = True;
        nextsame;
    }
    method DELETE-KEY(|c) {
        $.changed = True;
        nextsame;
    }

}
