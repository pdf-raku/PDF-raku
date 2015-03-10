use v6;

use PDF::Object :to-ast;

role PDF::Object::Array
    is PDF::Object {

    method content {
        :array[ self.map({ to-ast($_)}) ];
    }
}
