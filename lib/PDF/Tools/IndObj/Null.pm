use v6;
use PDF::Tools::IndObj;

class PDF::Tools::IndObj::Null
    is PDF::Tools::IndObj {
    has Mu $.null is rw;
    method content { :$.null };
}

