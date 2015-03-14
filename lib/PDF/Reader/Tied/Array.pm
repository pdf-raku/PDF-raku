use v6;

use PDF::Reader::Tied;

role PDF::Reader::Tied::Array
    does PDF::Reader::Tied {

    method AT-POS(|c) {
        $.reader
            ?? $.tied( callsame )
            !! callsame;
    }

    method ASSIGN-POS($key, $val) {
        $.changed = True;
        nextwith($key, $.tied($val) );
    }

    method BIND-POS($key, $val is rw) {
        $.changed = True;
        nextwith($key, $.tied($val) );
    }

    method DELETE-POS(|c) {
        $.changed = True;
        callsame;
    }

 }
