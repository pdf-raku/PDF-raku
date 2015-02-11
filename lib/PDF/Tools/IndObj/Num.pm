use v6;
use PDF::Tools::IndObj;

class PDF::Tools::IndObj::Num
    is PDF::Tools::IndObj {
    has Str $!pdf-type;
    has Numeric $.num;

    multi submethod BUILD( Int :$int!,  :$!pdf-type='int'  ) { $!num = $int  }
    multi submethod BUILD( Num :$real!, :$!pdf-type='real' ) { $!num = $real }

    method content { $!pdf-type => $.num };
}

