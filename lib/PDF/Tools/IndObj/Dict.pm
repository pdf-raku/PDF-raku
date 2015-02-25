use v6;

use PDF::Tools::Filter;
use PDF::Tools::IndObj ;
use PDF::Tools::IndObj::Type;
use PDF::Tools::Util :unbox;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
our class PDF::Tools::IndObj::Dict
    is PDF::Tools::IndObj
    does PDF::Tools::IndObj::Type {

    has Hash $.dict = {};

    method new-delegate( :$dict is copy, *%etc ) {
        $.delegate-class( :$dict ).new( :$dict, |%etc );
    }

    method content {
        :$.dict;
    }
}
