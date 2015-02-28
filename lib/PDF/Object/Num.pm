use v6;
use PDF::Object;

class PDF::Object::Num
    is PDF::Object {
    has Str $!pdf-type;
    has Numeric $.num;

    multi submethod BUILD( Int :$int!,  :$!pdf-type='int'  ) { $!num = $int  }
    multi submethod BUILD( Num :$real!, :$!pdf-type='real' ) { $!num = $real }

    method content { $!pdf-type => $.num };
}

