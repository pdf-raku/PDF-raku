use v6;

use PDF::Core::IndObj::Dict;

# /Type /Catalog - usually the root object in a PDF

class PDF::Core::IndObj::Catalog
    is PDF::Core::IndObj::Dict {

    method Pages is rw {
        self.dict<Pages>;
    }

}
