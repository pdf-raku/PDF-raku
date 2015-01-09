use v6;
use PDF::Core::IndObj;

class PDF::Core::IndObj::Null
    is PDF::Core::IndObj {
    has Mu $.null is rw;
    method content { :$.null };
}

