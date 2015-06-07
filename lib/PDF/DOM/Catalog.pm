use v6;

use PDF::Object::Dict;
use PDF::DOM;

# /Type /Catalog - usually the root object in a PDF

class PDF::DOM::Catalog
    is PDF::Object::Dict
    does PDF::DOM {

    method Pages is rw { self<Pages> }
    method Outlines is rw { self<Outlines> }
    method Resources is rw { self<Resources> }

    method finish {
        self<Pages>.finish;
    }

}
