use v6;

use PDF::Object::Dict;
use PDF::Object::Type;

# /Type /Page - describes a single PDF page

class PDF::Object::Type::Page
    is PDF::Object::Dict
    does PDF::Object::Type {

    method Parent is rw { self.dict<Parent> }
    method Resources is rw { self.dict<Resources> }
    method MediaBox is rw { self.dict<MediaBox> }
    method Contents is rw { self.dict<Contents> }

}
