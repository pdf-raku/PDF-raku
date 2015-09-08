use v6;
use PDF::Object;

role PDF::Object::Bool
    is PDF::Object {
    method content { :bool(?self) };
}

