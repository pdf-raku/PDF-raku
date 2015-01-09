use v6;
use PDF::Core::IndObj;

class PDF::Core::IndObj::Bool
    is PDF::Core::IndObj {
    has Bool $.bool is rw;
    method content { :$.bool };
}

