use v6;

use PDF::Object :to-ast;
use PDF::Object::Tree;

role PDF::Object::Array
    is PDF::Object
    does PDF::Object::Tree {

    method content {
        :array[ self.map({ to-ast($_)}) ];
    }
}
