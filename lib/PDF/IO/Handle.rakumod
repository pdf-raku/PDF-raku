use v6;

use PDF::IO;

class PDF::IO::Handle
    is PDF::IO {

    has IO::Handle $.value is required handles <read close eof seek slurp-rest>;
    has Str $!str;
    has UInt $.codes is rw;

    multi submethod TWEAK {
        $!value.seek( 0, SeekFromEnd );
        $!codes = $!value.tell;
        $!value.seek( 0, SeekFromBeginning );
    }

    multi method Str {
        $.byte-str(0, $!codes);
    }

    multi method subbuf(WhateverCode $whence!, |c --> Blob) {
        my UInt $from = $whence( $!codes );
        $.subbuf( $from, |c );
    }

    multi method subbuf( UInt $from!, UInt $length = $.codes - $from + 1 --> Blob) {
        $!value.seek( $from, SeekFromBeginning );
        $!value.read( $length );
    }

    method substr(|c) is DEPRECATED('Please use byte-str') {
        $.byte-str(|c);
    }
    multi method COERCE(IO::Handle:D $value!, |c ) {
        self.bless( :$value, |c );
    }
}
