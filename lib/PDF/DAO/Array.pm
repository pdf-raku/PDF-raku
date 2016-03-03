use v6;

use PDF::DAO;
use PDF::DAO::Tie::Array;

class PDF::DAO::Array
    does PDF::DAO
    is Array
    does PDF::DAO::Tie::Array {

    use PDF::DAO::Util :from-ast, :to-ast;

    my %seen{Any} = (); #= to catch circular references

    multi method new(Array $array!, |c) {
	self.new( :$array, |c );
    }

    multi method new(Array :$array = [], *%etc) {
        my $obj = %seen{$array};
        unless $obj.defined {
            temp %seen{$array} = $obj = self.bless(|%etc);
	    $obj.tie-init;
            # this may trigger cascading PDF::DAO::Tie coercians
            # e.g. native Array to PDF::DAO::Array
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
