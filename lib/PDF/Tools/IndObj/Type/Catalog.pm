use v6;

use PDF::Tools::IndObj::Dict;

# /Type /Catalog - usually the root object in a PDF

class PDF::Tools::IndObj::Type::Catalog
    is PDF::Tools::IndObj::Dict {

    method Pages is rw {
        self.dict<Pages>;
    }

}
