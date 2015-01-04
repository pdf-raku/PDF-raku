use v6;

use PDF::Core::Writer;
use PDF::Core::IndObj ;

our class PDF::Core::IndObj::Array
    is PDF::Core::IndObj {

    has Array $.array;

    method content {
        return { :$.array };
    }
}
