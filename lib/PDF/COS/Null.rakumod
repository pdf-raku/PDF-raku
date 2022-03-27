use v6;
use PDF::COS;

class PDF::COS::Null
    does PDF::COS
    is Any {
    method defined { False }
    method content { :null(Any) };
    multi method ACCEPTS(Any:U) { True }
}

