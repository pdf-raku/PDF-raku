use v6;

use PDF::Object;
use PDF::Object::Type;
use PDF::Object::Tie;
use PDF::Object::Tie::Hash;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
class PDF::Object::Dict
    is PDF::Object
    is Hash
    does PDF::Object::Type
    does PDF::Object::Tie::Hash {

    use PDF::Object::Util :from-ast, :to-ast-native;

    our %obj-cache = (); #= to catch circular references

    method new(Hash :$dict = {}, *%etc) {
        my Str $id = ~$dict.WHICH;
        my $obj = %obj-cache{$id};
        unless $obj.defined {
	    my %entries = PDF::Object::Tie::Hash.compose(self.WHAT);
            temp %obj-cache{$id} = $obj = self.bless(|%etc);
            # this may trigger cascading PDF::Object::Tie coercians
            # e.g. native Array to PDF::Object::Array
	    $obj.entries = %entries;
            $obj{.key} = from-ast(.value) for $dict.pairs;
            $obj.?cb-init;

	    if my $required = set %entries.pairs.grep({.value.is-required}).map({.key}) {
		my $missing = $required (-) $obj.keys;
		die "{self.WHAT.^name}: missing required field(s): $missing"
		    if $missing;
	    }
        }
        $obj;
    }

    method content {
        to-ast-native self;
    }
}
