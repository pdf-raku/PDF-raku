use v6;

use PDF::Tools::Filter;
use PDF::Object :box;
use PDF::Object::Type;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
our class PDF::Object::Dict
    is PDF::Object
    does PDF::Object::Type {

    has Hash $.dict;

    submethod BUILD( :$!dict is copy = {}) {
        self.setup-type( $!dict ); 
    }

    method content {
        box $!dict;
    }
}
