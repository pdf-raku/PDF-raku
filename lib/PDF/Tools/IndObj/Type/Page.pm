use v6;

use PDF::Tools::IndObj::Dict;
use PDF::Tools::IndObj::Type;

# /Type /Catalog - usually the root object in a PDF

class PDF::Tools::IndObj::Type::Page
    is PDF::Tools::IndObj::Dict
    does PDF::Tools::IndObj::Type {

    method Parent is rw { self.dict<Parent> }
    method Resource is rw { self.dict<Resources> }

}
