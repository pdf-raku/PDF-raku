use v6;

use PDF::Object::Dict;
use PDF::DOM;

# /Type /Outlines - the Outlines dictionary

class PDF::DOM::Outlines
    is PDF::Object::Dict
    does PDF::DOM {

    method Count is rw { self<Count> }
    method First is rw { self<First> }
    method Last  is rw { self<Last> }

}
