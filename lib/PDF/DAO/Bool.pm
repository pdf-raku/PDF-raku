use v6;
use PDF::DAO;

role PDF::DAO::Bool {
    # does PDF::DAO  - current restriction rakudo can't compose this
    has UInt $.obj-num is rw;
    has UInt $.gen-num is rw;
    has $.reader is rw;
    method content { :bool(?self) };
}

