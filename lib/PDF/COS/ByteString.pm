use v6;
use PDF::COS;

role PDF::COS::ByteString[Str $type = 'literal']
    does PDF::COS {
    method content { $type => self~'' };
}

role PDF::COS::ByteString does PDF::COS::ByteString['literal'] { }

