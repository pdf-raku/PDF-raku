use v6;

use PDF::Tools::IndObj::Dict;
use PDF::Tools::IndObj::Type;

# /Type /Page - describes a single PDF page

class PDF::Tools::IndObj::Type::Font
    is PDF::Tools::IndObj::Dict
    does PDF::Tools::IndObj::Type {

    method Subtype is rw { self.dict<Subtype> }
    method Name is rw { self.dict<Name> }
    method BaseFont is rw { self.dict<BaseFont> }
    method Encoding is rw { self.dict<Encoding> }

}

