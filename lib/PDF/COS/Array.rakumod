use v6;

use PDF::COS;
use PDF::COS::Tie::Array;

class PDF::COS::Array
    is Array
    does PDF::COS
    does PDF::COS::Tie::Array {

    use PDF::COS::Util :&from-ast, :&ast-coerce;
    my Lock $lock .= new;
    my %seen{Int} = (); #= to catch circular references

    submethod TWEAK(:$array!) {
        %seen{$*THREAD.id}{$array} = self;
        self.tie-init;
        # this may trigger cascading PDF::COS::Tie coercians
        # e.g. native Array to PDF::COS::Array
        self[$_] = from-ast($array[$_]) for ^$array;
        self.?cb-init();
        LEAVE %seen{$*THREAD.id}{$array}:delete;
    }

    method new(List() :$array = [], |c) {
        $lock.protect: {%seen{$*THREAD.id} //= my %{Any}};
        %seen{$*THREAD.id}{$array} // do {
            self.bless(:$array, |c);
        }
    }

    method content { ast-coerce self; }
    multi method COERCE(::?CLASS $array) { $array }
}
