use v6;
use PDF::COS;

my subset ContentType of Str where 'literal'|'hex-string';

role PDF::COS::ByteString[ContentType $type = 'literal']
    does PDF::COS {
    method content { $type => self~'' };
}

role PDF::COS::ByteString does PDF::COS::ByteString['literal'] { }

