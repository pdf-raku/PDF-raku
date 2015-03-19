use v6;

use PDF::Tools::Filter;
use PDF::Object :to-ast-native;
use PDF::Object::Type;
use PDF::Object::Tree;
use PDF::Object :from-ast;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
class PDF::Object::Dict
    is PDF::Object
    is Hash
    does PDF::Object::Type
    does PDF::Object::Tree {

    our %obj-cache = (); #= to catch circular references

    method new(Hash :$dict = {}, *%etc) {
        my $id = $dict.WHICH;
        my $obj = %obj-cache{$id};
        unless $obj {
            temp %obj-cache{$id} = $obj = self.bless(|%etc);
            # this may trigger PDF::Object::Tree coercians
            # e.g. native Array to PDF::Object::Array
            $obj{ .key } = from-ast(.value) for $dict.pairs;
            $obj.setup-type($obj);
        }
        $obj;
    }

    method content {
        to-ast-native self;
    }
}
