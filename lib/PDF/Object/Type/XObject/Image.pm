use v6;

use PDF::Object::Type::XObject;

class PDF::Object::Type::XObject::Image
    is PDF::Object::Type::XObject {

    method Width is rw { self<Width> }
    method Height is rw { self<Height> }
    method ColorSpace is rw { self<ColorSpace> }
    method BitsPerComponent is rw { self<BitsPerComponent> }

}
