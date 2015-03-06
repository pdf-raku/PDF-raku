use v6;

use PDF::Object :box;

role PDF::Object::Array
    is PDF::Object {

    method content {
        :array[ self.map({ box($_)}) ];
    }
}
