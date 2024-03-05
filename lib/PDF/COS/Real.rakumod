use v6;

role PDF::COS::Real {
    use PDF::COS;
    also does PDF::COS;
    method content { self+0 };
    multi method COERCE(Numeric:D() $real) {
        $real but $?ROLE;
    }
}

