use v6;

use PDF::Object::Dict;
use PDF::Object::Type;

# /Type /Outlines - the Outlines dictionary

class PDF::Object::Type::Outlines
    is PDF::Object::Dict
    does PDF::Object::Type {

    method Count is rw { self.dict<Count> }
    method First is rw { self.dict<First> }
    method Last  is rw { self.dict<Last> }

}
