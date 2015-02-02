use v6;
use PDF::Tools::IndObj;

class PDF::Tools::IndObj::Bool
    is PDF::Tools::IndObj {
    has Bool $.bool is rw;
    method content { :$.bool };
}

