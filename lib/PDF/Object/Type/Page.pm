use v6;

use PDF::Object::Dict;
use PDF::Object::Type;
use PDF::Object::Inheritance;

# /Type /Page - describes a single PDF page

class PDF::Object::Type::Page
    is PDF::Object::Dict
    does PDF::Object::Type
    does PDF::Object::Inheritance {

    method Parent is rw { self<Parent> }
    method Resources is rw { self<Resources> }
    method MediaBox is rw { self<MediaBox> }
    method Contents is rw { self<Contents> }

}
