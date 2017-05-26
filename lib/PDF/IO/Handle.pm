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
        $.substr(0, $!codes);
    }

    multi method subbuf( WhateverCode $whence!, |c --> Blob) {
        my UInt $from = $whence( $!codes );
        $.subbuf( $from, |c );
    }

    multi method subbuf( UInt $from!, UInt $length = $.codes - $from + 1 --> Blob) {
        with $!str {
            .substr-rw( $from, $length )
        }
        else {
            $!value.seek( $from, SeekFromBeginning );
            $!value.read( $length );
        }
    }

    method substr(|c) {
	$.subbuf(|c).decode('latin-1');
    }
}
