use v6;
use PDF::Storage::Input;

class PDF::Storage::Input::Str
    is PDF::Storage::Input
    is Str {

    has $!pos = 0;

    method read(UInt $n is copy) {
        my \n = min($n, $.codes - $!pos);
        my \s := $.substr-rw($!pos, n);
        $!pos += n;
        s.encode("latin-1");
    }
    multi method seek(UInt $n, SeekFromBeginning) {
        $!pos = min($n, $.codes);
    }
    multi method seek(UInt $n, SeekFromCurrent) {
        $!pos = min($!pos + $n, $.codes);
    }
    multi method seek(UInt $n, SeekFromEnd) {
        $!pos = max(0, $.codes - $n);
    }
    method slurp-rest {
        my \codes = $.codes;
        my \rest := $.substr-rw($!pos, codes - $!pos);
        $!pos = codes;
        rest;
    }
    method eof { $!pos >= $.codes }
    method close {}
}
