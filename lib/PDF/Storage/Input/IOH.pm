use v6;

use PDF::Storage::Input;

class PDF::Storage::Input::IOH
    is PDF::Storage::Input {

    has IO::Handle $.value is rw;
    has Str $!str;
    has UInt $.codes is rw;

    multi submethod BUILD( IO::Handle :$!value! ) {
        $!value.seek( 0, SeekFromEnd );
        $!codes = $!value.tell;
        $!value.seek( 0, SeekFromBeginning );
    }

    multi method Str {
        $.value.seek( 0, SeekFromBeginning );
        $!str //= $.value.slurp-rest;
    }

    multi method subbuf( WhateverCode $whence!, |c --> Buf) {
        my UInt $from = $whence( $.codes );
        $.subbuf( $from, |c );
    }

    multi method subbuf( UInt $from!, UInt $length = $.codes - $from + 1 --> Buf) {
        return $!str.substr( $from, $length )
            if $!str.defined;
        $!value.seek( $from, SeekFromBeginning );
        $.value.read( $length );
    }

    method substr(|c) {
	$.subbuf(|c).decode('latin-1');
    }
}
