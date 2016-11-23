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
    method eof { $!pos >= $.codes }
    method close {}
}
