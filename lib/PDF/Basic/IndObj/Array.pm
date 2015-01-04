use v6;

use PDF::Basic::Writer;
use PDF::Basic::IndObj ;

#| Stream - base class for specific indirect objects, e.g. ObjStm, XRef, ...
our class PDF::Basic::IndObj::Array
    is PDF::Basic::IndObj {

    has Array $.array;

    multi submethod BUILD(:$!array) {
    }

    method indobj-new( *%params ) {
        $.new( |%params );
    }

    method content {
        return { :$.array };
    }
}
