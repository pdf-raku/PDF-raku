use v6;

use PDF::COS;
use PDF::COS::Tie;
use PDF::COS::Tie::Hash;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
class PDF::COS::Dict
    is Hash
    does PDF::COS
    does PDF::COS::Tie::Hash {

    use PDF::COS::Util :from-ast, :ast-coerce;

    my %seen{Any} = (); #= to catch circular references

    method new(Hash() :$dict = {}, |c) {
        my $obj = %seen{$dict};
        without $obj {
            temp %seen{$dict} = $obj = self.bless(|c);
            $obj.tie-init;
            my %entries := $obj.entries;
            my %alias = %entries.pairs.map({ .value.cos.alias => .key}).grep(*.key);
            # this may trigger cascading PDF::COS::Tie coercians
            # e.g. native Array to PDF::COS::Array
            $obj{%alias{.key} // .key} = from-ast(.value) for $dict.pairs.sort;
            $obj.?cb-init;

	    if my $required = set %entries.pairs.grep(*.value.cos.is-required).map(*.key) {
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
    multi method COERCE(Hash:D $dict is raw) {
        self.new: :$dict;
    }
}
