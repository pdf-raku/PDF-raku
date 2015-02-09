use v6;

use PDF::Tools::Input;

class PDF::Tools::Input::IOH
    is PDF::Tools::Input {

    has IO::Handle $.value is rw;
    has Int $.chars is rw;

    BEGIN constant SEEK-FROM-START = 0;
    BEGIN constant SEEK-FROM-EOF = 2;

    multi submethod BUILD( IO::Handle :$!value! ) {
        $!value.seek( 0, SEEK-FROM-EOF );
        $!chars = $!value.tell;
        $!value.seek( 0, SEEK-FROM-START );
    }

    multi method Str( ) {
        $.value.seek( 0, SEEK-FROM-START );
        $.value.slurp-rest;
    }

    multi method substr( WhateverCode $from-whatever!, $length? ) {
        my $from = $from-whatever( $.chars );
        $.substr( $from, $length );
    }

    multi method substr( Int $from!, $length is copy ) {
        $!value.seek( $from, SEEK-FROM-START );
        $length //= $.chars - $from + 1;
        my $buf = $.value.read( $length );
        $buf.decode('latin-1');
    }
}
