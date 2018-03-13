use v6;

use PDF::COS;
use PDF::COS::Tie::Array;

class PDF::COS::Array
    is Array
    does PDF::COS
    does PDF::COS::Tie::Array {

    use PDF::COS::Util :from-ast, :to-ast;

    my %seen{Any} = (); #= to catch circular references

    method new(List :$array = [], |c) {
        my $obj = %seen{$array};
        without $obj {
            temp %seen{$array} = $obj = self.bless(:$array, |c);
            $obj.tie-init;
            # this may trigger cascading PDF::COS::Tie coercians
            # e.g. native Array to PDF::COS::Array
            $obj[ .key ] = from-ast(.value) for $array.pairs;
            $obj.?cb-init;
         }
        $obj;
    }

    my %content-cache{Any} = ();

    method content {
	my $obj = self;
        my $array = %content-cache{$obj};
        unless $array {
	    # to-ast may recursively call $.content. cache to break any cycles
            temp %content-cache{$obj} = $array = [];
            $array.push: to-ast($_)
                for self.list;
        }
        :$array;
    }
}
