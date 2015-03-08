use v6;

use PDF::Object::Dict;
use PDF::Object::Type;

# /Type /Pages - a node in the page tree

class PDF::Object::Type::Pages
    is PDF::Object::Dict
    does PDF::Object::Type {

    method Count is rw { self<Count> }
    method Kids is rw { self<Kids> }

}
