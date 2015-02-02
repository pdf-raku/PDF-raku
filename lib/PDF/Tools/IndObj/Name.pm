use v6;
use PDF::Tools::IndObj;

class PDF::Tools::IndObj::Name
    is PDF::Tools::IndObj {
    has Str $.name is rw;
    method content { :$.name };
}

