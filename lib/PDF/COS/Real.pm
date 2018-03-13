use v6;
use PDF::COS;

role PDF::COS::Real
    does PDF::COS {
     method content { :real(self + 0) };
}

