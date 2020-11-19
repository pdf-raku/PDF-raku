use v6;
use PDF::COS;

role PDF::COS::Real
    does PDF::COS {
     method content { :real(self + 0) };
     multi method COERCE(Numeric:D() $real) {
         $real but $?ROLE;
     }
}

