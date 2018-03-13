use v6;
use PDF::COS;

role PDF::COS::ByteString
    does PDF::COS {
    has Str $.type is rw;

    method content { $!type => self~'' };
}

