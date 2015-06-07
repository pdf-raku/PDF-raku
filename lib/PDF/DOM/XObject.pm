use v6;

use PDF::Object::Stream;
use PDF::DOM;

# /Type /XObject - describes an abastract XObject. See also
# PDF::DOM::XObject::Form, PDF::DOM::XObject::Image

class PDF::DOM::XObject
    is PDF::Object::Stream
    does PDF::DOM {

    method Resources is rw { self<Resources> }
    method BBox is rw { self<BBox> }

}
