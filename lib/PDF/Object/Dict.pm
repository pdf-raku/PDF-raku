use v6;

use PDF::Tools::Filter;
use PDF::Object :to-ast-native;
use PDF::Object::Type;
use PDF::Object::Tree;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
class PDF::Object::Dict
    is PDF::Object
    is Hash
    does PDF::Object::Type
    does PDF::Object::Tree {

    method new(Hash :$dict = {}, *%etc) {
        my $obj = self.bless(|%etc);
        # this may trigger PDF::Object::Tree type coercians
        # e.g. native Array to PDF::Object::Array
        $obj{ .key } := .value for $dict.pairs;
        $obj.setup-type($obj);
        $obj;
    }

    method content {
        to-ast-native self;
    }
}
