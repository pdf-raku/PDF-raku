use v6;

use PDF::Storage::Crypt;
use PDF::Storage::Crypt::AST;

class PDF::Storage::Crypt::AES
    is PDF::Storage::Crypt
    does PDF::Storage::Crypt::AST {

    use PDF::Storage::Blob;
    use PDF::Storage::Util :resample;

    method type { 'AESV2' }

    method !object-key(UInt $obj-num, UInt $gen-num ) {
	die "encryption has not been authenticated"
	    unless $.key;

	my uint8 @obj-bytes = resample([ $obj-num ], 32, 8).reverse;
	my uint8 @gen-bytes = resample([ $gen-num ], 32, 8).reverse;
	my uint8 @obj-key = flat $.key.list, @obj-bytes[0 .. 2], @gen-bytes[0 .. 1], 0x73, 0x41, 0x6C, 0x54; # 'sAIT'

	my UInt $size = +@obj-key;
	$.md5( @obj-key );
	my $key = $.md5( @obj-key );
	$size < 16 ?? $key[0 ..^ $size] !! $key;
    }

    multi method crypt( Str $text, |c) {
	$.crypt( $text.encode("latin-1"), |c ).decode("latin-1");
    }

    multi method crypt( $bytes, Str :$mode! where 'encrypt'|'decrypt',
                        UInt :$obj-num!, UInt :$gen-num! ) is default {
	# Algorithm 3.1

        my $obj-key = self!object-key( $obj-num, $gen-num );

        self."$mode"( $obj-key, $bytes);
    }

    method encrypt( $key, $dec --> Buf) {
        my @iv = (^256).pick xx 16;
        my $enc-iv = Buf.new: @iv;
        $enc-iv.append: $.aes-encrypt($key, $dec, :@iv );
        $enc-iv;
    }

    method decrypt( $key, $enc-iv) {
        my @iv = $enc-iv[0 ..^ 16];
        my @enc = +$enc-iv > 16 ?? $enc-iv[16 .. *] !! [];
        my $dec = $.aes-decrypt($key, @enc, :@iv );
        $dec;
    }

}
