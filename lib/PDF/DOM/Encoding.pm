use v6;

use PDF::Object::Dict;

# /Type /Pages - a node in the page tree

class PDF::DOM::Encoding
    is PDF::Object::Dict
    does PDF::DOM {

    method BaseEncoding is rw { self<BaseEncoding> }
    method Differences  is rw { self<Differences> }

}
