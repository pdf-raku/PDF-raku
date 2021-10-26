use v6;
use PDF::COS;

role PDF::COS::Bool
    does PDF::COS {
    method content { :bool(?self) };
    proto method COERCE($) {*}
    multi method COERCE(Bool:D() $bool) {
        $bool but $?ROLE;
    }
}

