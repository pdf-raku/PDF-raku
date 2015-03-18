use v6;

use PDF::Object :to-ast;
use PDF::Object::Tree;

class PDF::Object::Array
    is PDF::Object
    is Array
    does PDF::Object::Tree {

    method new(Array :$array = [], *%etc) {
        my $obj = self.bless(|%etc);
        # this may trigger PDF::Object::Tree type coercians
        # e.g. native Array to PDF::Object::Array
        $obj[ .key ] := .value for $array.pairs;
        $obj;
    }

    method content {
        :array[ self.map({ to-ast($_)}) ];
    }
}
