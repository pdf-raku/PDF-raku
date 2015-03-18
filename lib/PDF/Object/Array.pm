use v6;

use PDF::Object :to-ast;
use PDF::Reader::Tied;

role PDF::Object::Array
    is PDF::Object
    does PDF::Reader::Tied {

    method content {
        :array[ self.map({ to-ast($_)}) ];
    }
}
