use v6;

use PDF::Tools::IndObj::Dict;
use PDF::Tools::IndObj::Type;

# /Type /Catalog - usually the root object in a PDF

class PDF::Tools::IndObj::Type::Catalog
    is PDF::Tools::IndObj::Dict
    does PDF::Tools::IndObj::Type {

    method Pages is rw { self.dict<Pages> }

}
