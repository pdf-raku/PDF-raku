use v6;
use PDF::COS;

role PDF::COS::Name
    does PDF::COS {

    method content {
        :name(self~'')
    }
}

