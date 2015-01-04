use v6;

use PDF::Basic::Writer;
use PDF::Basic::IndObj ;

our class PDF::Basic::IndObj::Array
    is PDF::Basic::IndObj {

    has Array $.array;

    method indobj-new( *%params ) {
        $.new( |%params );
    }

    method content {
        return { :$.array };
    }
}
