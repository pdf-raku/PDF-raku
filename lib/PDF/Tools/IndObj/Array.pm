use v6;

use PDF::Tools::IndObj ;

our class PDF::Tools::IndObj::Array
    is PDF::Tools::IndObj {

    has Array $.array;

    method content {
        return { :$.array };
    }
}
