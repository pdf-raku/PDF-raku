use v6;
use PDF::Object;

class PDF::Object::Null
    is PDF::Object
    is Any {
    method content { :null(Any) };
}

