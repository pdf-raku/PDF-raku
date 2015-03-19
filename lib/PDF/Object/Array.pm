use v6;

use PDF::Object :to-ast;
use PDF::Object::Tree;
use PDF::Object :from-ast;

class PDF::Object::Array
    is PDF::Object
    is Array
    does PDF::Object::Tree {

    method new(Array :$array = [], *%etc) {
        my $obj = self.bless(|%etc);
        # this may trigger PDF::Object::Tree coercians
        # e.g. native Array to PDF::Object::Array
        $obj[ .key ] = from-ast(.value) for $array.pairs;
        $obj;
    }

    method content {
        :array[ self.map({ to-ast($_)}) ];
    }
}
