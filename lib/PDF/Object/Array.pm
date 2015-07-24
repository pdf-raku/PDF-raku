use v6;

use PDF::Object;
use PDF::Object::Tie::Array;

class PDF::Object::Array
    is PDF::Object
    is Array
    does PDF::Object::Tie::Array {

    use PDF::Object::Util :from-ast, :to-ast;

    our %obj-cache = (); #= to catch circular references

    method new(Array :$array = [], *%etc) {
        my Str $id = ~$array.WHICH;
        my $obj = %obj-cache{$id};
        unless $obj.defined {
            temp %obj-cache{$id} = $obj = self.bless(|%etc);
            # this may trigger cascading PDF::Object::Tie coercians
            # e.g. native Array to PDF::Object::Array
            $obj[ .key ] = from-ast(.value) for $array.pairs;
	    $obj."$_"() for $obj.tied-atts.keys.grep({ ! $obj{$_}:exists });
            $obj.?cb-setup-type($obj);
        }
        $obj;
    }

    our %content-cache = ();

    method content {
        my Str $id = self.id;
        my $array = %content-cache{$id};
        unless $array {
            temp %content-cache{$id} = $array = [];
            $array.push: to-ast($_)
                for self.list;
        }
        :$array;
    }
}
