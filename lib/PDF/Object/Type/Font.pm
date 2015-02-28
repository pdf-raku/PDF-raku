use v6;

use PDF::Object::Dict;
use PDF::Object::Type;

# /Type /Page - describes a single PDF page

class PDF::Object::Type::Font
    is PDF::Object::Dict
    does PDF::Object::Type {

    method Subtype is rw { self.dict<Subtype> }
    method Name is rw { self.dict<Name> }
    method BaseFont is rw { self.dict<BaseFont> }
    method Encoding is rw { self.dict<Encoding> }

}

