use v6;

use PDF::Basic::IndObj::Dict;

# /Type /Catalog - usually the root object in a PDF

class PDF::Basic::IndObj::Catalog
    is PDF::Basic::IndObj::Dict {

    method Pages is rw {
        self.dict<Pages>;
    }

}
