use v6;

unit class PDF::IO::Str;

use PDF::IO;
also does PDF::IO;
also is Str;

has $!pos = 0;
has Blob[uint8] $!ords;
method ords {
    $!ords //= self.encode("latin-1");
}

method subbuf(|c) { $.ords.subbuf(|c) }
method read(UInt $n = $.codes - $!pos) {
    my \n = min($n, $.codes - $!pos);
    my \buf := Buf[uint8].new: $.subbuf($!pos, n);
    $!pos += n;
    buf;
}
multi method seek(UInt $n, SeekFromBeginning) {
    $!pos = min($n, $.codes);
}
multi method seek(Int $n, SeekFromCurrent) {
    $!pos = max(0, min($!pos + $n, $.codes));
}
multi method seek(Int $n, SeekFromEnd) {
    $!pos = $n >= 0
        ?? $.codes
        !! max(0, $.codes + $n);
}
method slurp {
    my \codes = $.codes;
    my \rest := $.ords.subbuf($!pos, codes - $!pos);
    $!pos = codes;
    rest;
}
method eof { $!pos >= $.codes }
method close {}

multi method COERCE(Str:D $value!, |c) {
    self.bless( :$value, |c );
}
multi method COERCE(::?CLASS:D $_) is default { $_ }
multi method COERCE( Blob:D $_!, |c) {
    my $value = .decode: "latin-1";
    self.bless( :$value, |c );
}
