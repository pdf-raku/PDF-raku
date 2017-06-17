use v6;

use PDF::DAO;
use PDF::DAO::Tie;
use PDF::DAO::Tie::Hash;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
class PDF::DAO::Dict
    is Hash
    does PDF::DAO
    does PDF::DAO::Tie::Hash {

    use PDF::DAO::Util :from-ast, :ast-coerce;

    my %seen{Any} = (); #= to catch circular references

    method new(Hash :$dict = {}, |c) is default {
        my $obj = %seen{$dict};
        without $obj {
            temp %seen{$dict} = $obj = self.bless(|c);
            $obj.tie-init;
            # this may trigger cascading PDF::DAO::Tie coercians
            # e.g. native Array to PDF::DAO::Array
            $obj{.key} = from-ast(.value) for $dict.pairs;
            $obj.?cb-init;

	    if my $required = set $obj.entries.pairs.grep(*.value.tied.is-required).map(*.key) {
		my $missing = $required (-) $obj.keys;
		die "{self.WHAT.^name}: missing required field(s): $missing"
		    if $missing;
	    }
        }
        $obj;
    }

    method content {
        ast-coerce self;
    }
}
