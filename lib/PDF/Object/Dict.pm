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

    multi method new(Hash $dict!, |c) {
	self.new( :$dict, |c );
    }

    multi method new(Hash :$dict = {}, *%etc) is default {
        my Str $id = ~$dict.WHICH;
        my $obj = %obj-cache{$id};
        unless $obj.defined {
            temp %obj-cache{$id} = $obj = self.bless(|%etc);
	    $obj.tie-init;
            # this may trigger cascading PDF::Object::Tie coercians
            # e.g. native Array to PDF::Object::Array
            $obj{.key} = from-ast(.value) for $dict.pairs;
            $obj.?cb-init;

	    if my $required = set $obj.entries.pairs.grep({.value.tied.is-required}).map({.key}) {
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
