use v6;
use PDF::COS;

role PDF::COS::Bool {
    # does PDF::COS  - current restriction rakudo can't compose this
    has UInt $.obj-num is rw;
    has UInt $.gen-num is rw;
    has $.reader is rw;
    method content { :bool(?self) };
}

