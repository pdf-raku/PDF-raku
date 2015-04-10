use v6;

use PDF::Object::Stream;
use PDF::Object::Type;

# /Type /XObject - describes an abastract XObject. See also
# PDF::Object::Type::XObject::Form, PDF::Object::Type::XObject::Image

class PDF::Object::Type::XObject
    is PDF::Object::Stream
    does PDF::Object::Type {

    method Resources is rw { self<Resources> }
    method BBox is rw { self<BBox> }

}
