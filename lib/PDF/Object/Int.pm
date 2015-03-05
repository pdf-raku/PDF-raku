use v6;
use PDF::Object;

role PDF::Object::Int
    is PDF::Object {
     method content { :int(self+0) };
}

