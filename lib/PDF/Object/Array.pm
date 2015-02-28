use v6;

use PDF::Object ;

our class PDF::Object::Array
    is PDF::Object {

    has Array $.array;

    method content {
        return { :$.array };
    }
}
