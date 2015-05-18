use v6;

use PDF::Object::Dict;

# /Type /Pages - a node in the page tree

class PDF::Object::Type::OBJR
    is PDF::Object::Dict
    does PDF::Object::Type {

    method Pg is rw { self<Pg> }
    method Obj  is rw { self<Obj> }

}
