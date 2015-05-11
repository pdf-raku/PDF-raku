use v6;

use PDF::Object :to-ast;
use PDF::Object::Tree;
use PDF::Object :from-ast;

class PDF::Object::Array
    is PDF::Object
    is Array
    does PDF::Object::Tree {

    our %obj-cache = (); #= to catch circular references

    method new(Array :$array = [], *%etc) {
        my $id = ~$array.WHICH;
        my $obj = %obj-cache{$id};
        unless $obj.defined {
            temp %obj-cache{$id} = $obj = self.bless(|%etc);
            # this may trigger cascading PDF::Object::Tree coercians
            # e.g. native Array to PDF::Object::Array
            $obj[ .key ] = from-ast(.value) for $array.pairs;
        }
        $obj;
    }

    our %content-cache = ();

    method content {
        my $id = self.id;
        my $array = %content-cache{$id};
        unless $array {
            temp %content-cache{$id} = $array = [];
            $array.push: to-ast($_)
                for self.list;
        }
        :$array;
    }
}
