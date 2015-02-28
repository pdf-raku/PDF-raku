use v6;
use PDF::Object;

class PDF::Object::String
    is PDF::Object {
    has Str $.type is rw;
    has Str $.value is rw;

    multi submethod BUILD( :$hex-string! ) {
        $!type = 'hex-string';
        $!value = $hex-string;
    }

    multi submethod BUILD( :$literal! ) {
        $!type = 'literal';
        $!value = $literal;
    }

    method content { $!type => $!value };
}

