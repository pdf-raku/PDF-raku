use v6;

use PDF::Object::Stream;
##use PDF::Object::Type;

# /Type /Page - describes a single PDF page

class PDF::Object::Type::XObject
    is PDF::Object::Stream
    does PDF::Object::Type {

    method Subtype is rw { self<Subtype> }
    method Resources is rw { self<Resources> }
    method BBox is rw { self<BBox> }

}
