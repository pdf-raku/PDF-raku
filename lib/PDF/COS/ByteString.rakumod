use v6;
use PDF::COS :LatinStr;

my subset ContentType of Str where 'literal'|'hex-string';

role PDF::COS::ByteString[ContentType $type = 'literal']
    does PDF::COS {
    method content { $type => self.fmt };
    multi method COERCE(LatinStr $v is raw) {
        self.coerce: |$type => $v;
    }
}

role PDF::COS::ByteString does PDF::COS::ByteString['literal'] { }

