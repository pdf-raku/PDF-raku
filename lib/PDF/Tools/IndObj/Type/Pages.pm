use v6;

use PDF::Tools::IndObj::Dict;
use PDF::Tools::IndObj::Type;

# /Type /Pages - a node in the page tree

class PDF::Tools::IndObj::Type::Pages
    is PDF::Tools::IndObj::Dict
    does PDF::Tools::IndObj::Type {

    method Count is rw { self.dict<Count> }
    method Kids is rw { self.dict<Kids> }

}
