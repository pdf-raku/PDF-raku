use v6;

use PDF::Object::Dict;
use PDF::Object::Type;

# /Type /Outlines - the Outlines dictionary

class PDF::Object::Type::Outlines
    is PDF::Object::Dict
    does PDF::Object::Type {

    method Count is rw { self<Count> }
    method First is rw { self<First> }
    method Last  is rw { self<Last> }

}
