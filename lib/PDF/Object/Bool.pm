use v6;
use PDF::Object;

class PDF::Object::Bool
    is PDF::Object {
    has Bool $.bool is rw;
    method content { :$.bool };
}

