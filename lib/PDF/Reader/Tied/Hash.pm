use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Hash
    does PDF::Reader::Tied {

    method AT-KEY(|c) {
        $.reader
            ?? $.tied( callsame )
            !! callsame
    }

    method ASSIGN-KEY($key, $val) {
        $.changed = True;
        nextwith($key, $.tied($val) );
    }

    method BIND-KEY($key, $val is rw) {
        $.changed = True;
        nextwith($key, $.tied($val) )
    }
    method DELETE-KEY(|c) {
        $.changed = True;
        callsame;
    }

}
