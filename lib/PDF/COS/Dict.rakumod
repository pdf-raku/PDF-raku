use v6;

use PDF::COS;
use PDF::COS::Tie;
use PDF::COS::Tie::Hash;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
class PDF::COS::Dict
    is Hash
    does PDF::COS
    does PDF::COS::Tie::Hash {

    use PDF::COS::Util :&from-ast, :&ast-coerce;
    my %seen{Hash} = (); #= to catch circular references
    my Lock $seen-lock .= new;

    submethod TWEAK(:$dict!, :$seen-lock) {
        %seen{$dict} = self;
        .unlock with $seen-lock;
        self.tie-init;
        my %entries := self.entries;
        my %alias = %entries.pairs.map({ .value.cos.alias => .key}).grep(*.key);
        # this may trigger cascading PDF::COS::Tie coercians
        # e.g. native Array to PDF::COS::Array
        self{%alias{.key} // .key} = from-ast(.value) for $dict.pairs.sort;
        self.?cb-init;

	if set %entries.pairs.grep(*.value.cos.is-required)».key -> $required {
	    my $missing = $required (-) self.keys;
	    die "{self.WHAT.^name}: missing required field(s): $missing"
	    if $missing;
	}
    }

    method new(Hash() :$dict = {}, |c) {
        $seen-lock.lock;
        with %seen{$dict} -> $obj {
            $seen-lock.unlock;
            $obj;
        }
        else {
            LEAVE $seen-lock.protect: { %seen{$dict}:delete }
            self.bless(:$dict, :$seen-lock, |c);
        }
    }

    method content { ast-coerce self; }
    multi method COERCE(::?CLASS $dict) { $dict }
}
