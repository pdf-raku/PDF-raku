use v6;
use PDF::Object;

role PDF::Object::String
    is PDF::Object {
    has Str $.type is rw;

    method content { $!type => self~'' };
}

