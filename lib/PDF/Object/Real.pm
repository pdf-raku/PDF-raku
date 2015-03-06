use v6;
use PDF::Object;

role PDF::Object::Real
    is PDF::Object {
     method content { :real(self + 0) };
}

