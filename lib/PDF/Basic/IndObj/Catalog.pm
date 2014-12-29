use v6;

use PDF::Basic::IndObj::Stream;

# /Type /Catalog - usually the root object in a PDF

class PDF::Basic::IndObj::Catalog
    is PDF::Basic::IndObj::Stream {

    method Pages is rw {
        self.dict<Pages>;
    }

}
