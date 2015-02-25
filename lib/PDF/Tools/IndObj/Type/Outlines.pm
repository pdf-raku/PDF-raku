use v6;

use PDF::Tools::IndObj::Dict;
use PDF::Tools::IndObj::Type;

# /Type /Outlines - the Outlines dictionary

class PDF::Tools::IndObj::Type::Outlines
    is PDF::Tools::IndObj::Dict
    does PDF::Tools::IndObj::Type {

    method Count is rw { self.dict<Count> }
    method First is rw { self.dict<First> }
    method Last  is rw { self.dict<Last> }

}
