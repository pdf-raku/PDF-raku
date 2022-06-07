use v6;
use PDF::COS;;

role PDF::COS::Int
    does PDF::COS {

    use PDF::COS::Util :&flag-is-set;
    method flag-is-set(uint $flag-num) is DEPRECATED returns Bool {
        flag-is-set(self, $flag-num);
    }

    method content { self+0 };

    multi method COERCE(Int:D() $int) {
        $int but $?ROLE;
    }
}

