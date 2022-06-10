use v6;

use PDF::COS;
use PDF::COS::Tie::Array;

class PDF::COS::Array
    is Array
    does PDF::COS
    does PDF::COS::Tie::Array {

    use PDF::COS::Util :&from-ast, :&ast-coerce;
    my %seen{List} = (); #= to catch circular references
    my Lock $seen-lock .= new;

    submethod TWEAK(:$array!, :$seen-lock) {
        %seen{$array} = self;
        .unlock with $seen-lock;
        self.tie-init;
        # this may trigger cascading PDF::COS::Tie coercians
        # e.g. native Array to PDF::COS::Array
        self[$_] = from-ast($array[$_]) for ^$array;
        self.?cb-init();
    }

    method new(List() :$array = [], |c) {
        $seen-lock.lock;
        with %seen{$array} -> $obj {
            $seen-lock.unlock;
            $obj;
        }
        else {
            LEAVE $seen-lock.protect: { %seen{$array}:delete }
            self.bless(:$array, :$seen-lock, |c);
        }
    }

    method content { ast-coerce self; }
    multi method COERCE(::?CLASS $array) { $array }
}
