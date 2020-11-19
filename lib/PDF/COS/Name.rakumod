use v6;
use PDF::COS;

role PDF::COS::Name
    does PDF::COS {

    method content {
        :name(self~'')
    }
    proto method COERCE($){*}
    multi method COERCE(PDF::COS::Name:D $_) { $_ }
    multi method COERCE(Str:D() $str) { $str but PDF::COS::Name }
}

