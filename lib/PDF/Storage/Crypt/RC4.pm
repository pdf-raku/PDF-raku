use v6;

use PDF::Storage::Crypt;
use PDF::Storage::Crypt::AST;

class PDF::Storage::Crypt::RC4
    is PDF::Storage::Crypt
    does PDF::Storage::Crypt::AST {

    use PDF::Storage::Blob;
    use PDF::Storage::Util :resample;

    method type { 'V2' }

    method !object-key(UInt $obj-num, UInt $gen-num ) {
	die "encryption has not been authenticated"
	    unless $.key;

	my uint8 @obj-bytes = resample([ $obj-num ], 32, 8).reverse;
	my uint8 @gen-bytes = resample([ $gen-num ], 32, 8).reverse;
	my uint8 @obj-key = flat $.key.list, @obj-bytes[0 .. 2], @gen-bytes[0 .. 1];

	my UInt $size = +@obj-key;
	my $key = $.md5( @obj-key );
	$size < 16 ?? $key[0 ..^ $size] !! $key;
    }

    multi method crypt( Str $text, |c --> Str) {
	$.crypt( $text.encode("latin-1"), |c ).decode("latin-1");
    }

    multi method crypt( $bytes, UInt :$obj-num!, UInt :$gen-num! ) is default {
	# Algorithm 3.1

        my $obj-key = self!object-key( $obj-num, $gen-num );
	Buf.new: PDF::Storage::Crypt::rc4-crypt( $obj-key, $bytes );
    }

}
