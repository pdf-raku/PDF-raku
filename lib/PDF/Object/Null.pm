use v6;
use PDF::Object;

class PDF::Object::Null
    is PDF::Object {
    has Mu $.null is rw;
    method content { :$.null };
}

