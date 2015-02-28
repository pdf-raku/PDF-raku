use v6;
use PDF::Object;

class PDF::Object::Name
    is PDF::Object {
    has Str $.name is rw;
    method content { :$.name };
}

