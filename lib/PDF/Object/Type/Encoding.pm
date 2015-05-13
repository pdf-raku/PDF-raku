use v6;

use PDF::Object::Dict;

# /Type /Pages - a node in the page tree

class PDF::Object::Type::Encoding
    is PDF::Object::Dict
    does PDF::Object::Type {

    method BaseEncoding is rw { self<BaseEncoding> }
    method Differences  is rw { self<Differences> }

}
