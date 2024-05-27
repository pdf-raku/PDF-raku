use v6;

unit role PDF::COS::Bool;

use PDF::COS;
also does PDF::COS;

method content { :bool(?self) };
proto method COERCE($) {*}
multi method COERCE(Bool:D() $bool) {
    $bool but $?ROLE;
}


