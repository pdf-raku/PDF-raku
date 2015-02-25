use v6;

use PDF::Tools::IndObj::Dict;
use PDF::Tools::IndObj::Type;

# /Type /Page - describes a single PDF page

class PDF::Tools::IndObj::Type::Page
    is PDF::Tools::IndObj::Dict
    does PDF::Tools::IndObj::Type {

    method Parent is rw { self.dict<Parent> }
    method Resources is rw { self.dict<Resources> }
    method MediaBox is rw { self.dict<MediaBox> }
    method Contents is rw { self.dict<Contents> }

}
