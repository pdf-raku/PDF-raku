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
        my %alias := self.aliases;
        # this may trigger cascading PDF::COS::Tie coercians
        # e.g. native Array to PDF::COS::Array
        self{%alias{.key} // .key} = from-ast(.value) for $dict.pairs.sort;
        self.?cb-init;

	if self.required-entries -> $required  {
	    my @missing = $required.keys.grep: {self{$_}:!exists};
	    die "{self.WHAT.^name}: missing required field(s): {@missing.sort.join: ','}"
	        if @missing;
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
