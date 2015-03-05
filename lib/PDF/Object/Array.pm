use v6;

use PDF::Object :box;

our class PDF::Object::Array
    is PDF::Object {

    has Array $.array;

    method content {
        :array[ $.array.map({ box($_)}) ];
    }
}
