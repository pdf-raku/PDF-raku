use v6;

use PDF::Reader;
use PDF::Object;

role PDF::Reader::Tied {

    has PDF::Reader $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

}
