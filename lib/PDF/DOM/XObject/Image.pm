use v6;

use PDF::DOM::XObject;

class PDF::DOM::XObject::Image
    is PDF::DOM::XObject {

    method Width is rw { self<Width> }
    method Height is rw { self<Height> }
    method ColorSpace is rw { self<ColorSpace> }
    method BitsPerComponent is rw { self<BitsPerComponent> }

}
