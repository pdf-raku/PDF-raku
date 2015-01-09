use v6;
use PDF::Core::IndObj;

class PDF::Core::IndObj::Name
    is PDF::Core::IndObj {
    has Str $.name is rw;
    method content { :$.name };
}

