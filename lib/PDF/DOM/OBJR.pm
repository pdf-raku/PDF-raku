use v6;

use PDF::Object::Dict;

# /Type /Pages - a node in the page tree

class PDF::DOM::OBJR
    is PDF::Object::Dict
    does PDF::DOM {

    method Pg is rw { self<Pg> }
    method Obj  is rw { self<Obj> }

}
