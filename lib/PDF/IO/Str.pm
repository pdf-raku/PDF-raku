use v6;
use PDF::IO;

class PDF::IO::Str
    is PDF::IO
    is Str {

    has $!pos = 0;
    has Blob[uint8] $!ords;
    method ords {
        $!ords //= self.encode("latin-1");
    }

    method read(UInt $n is copy) {
        my \n = min($n, $.codes - $!pos);
        my \buf := Buf[uint8].new: $.ords.subbuf($!pos, n);
        $!pos += n;
        buf;
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
        my \rest := $!pos == 0
            ?? .Str
            !! $.ords.subbuf($!pos, codes - $!pos).decode: "latin-1";
        $!pos = codes;
        rest;
    }
    method eof { $!pos >= $.codes }
    method close {}
}
