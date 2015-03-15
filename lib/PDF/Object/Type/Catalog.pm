use v6;

use PDF::Object::Dict;
use PDF::Object::Type;

# /Type /Catalog - usually the root object in a PDF

class PDF::Object::Type::Catalog
    is PDF::Object::Dict
    does PDF::Object::Type {

    method Pages is rw { self<Pages> }
    method Outlines is rw { self<Outlines> }
    method Resources is rw { self<Resources> }

}
