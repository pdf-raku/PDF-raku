use v6;

use PDF::IO::Crypt;
use PDF::IO::Crypt::AST;

class PDF::IO::Crypt::AESV2
    is PDF::IO::Crypt
    does PDF::IO::Crypt::AST {

    use OpenSSL::CryptTools;
    use OpenSSL::Digest;
    use PDF::IO::Util :pack;

    constant KeyLen = 16;

    submethod TWEAK(UInt :$Length = 128, |c) {
        die "unsupported AES encryption key length: $Length"
            unless $Length ~~ 16|128;
    }

    method type { 'AESV2' }

    method !aes-encrypt($key, $msg, :$iv --> Buf) {
        OpenSSL::CryptTools::encrypt( :aes128, $msg, :$key, :$iv);
    }

    method !aes-decrypt($key, $msg, :$iv --> Buf) {
        OpenSSL::CryptTools::decrypt( :aes128, $msg, :$key, :$iv);
    }

    method !object-key(UInt $obj-num, UInt $gen-num ) {
	die "encryption has not been authenticated"
	    unless $.key;

	my uint8 @obj-bytes = pack-le($obj-num, 32);
	my uint8 @gen-bytes = pack-le($gen-num, 32);
	my uint8 @obj-key = flat $.key.list, @obj-bytes[0 .. 2], @gen-bytes[0 .. 1], 0x73, 0x41, 0x6C, 0x54; # 'sAIT'

	md5( Buf.new(@obj-key) );
    }

    multi method crypt( Str $text, |c) {
	$.crypt( $text.encode("latin-1"), |c ).decode("latin-1");
    }

    multi method crypt( $bytes, Str :$mode! where 'encrypt'|'decrypt',
                        UInt :$obj-num!, UInt :$gen-num! ) {

        my $obj-key = self!object-key( $obj-num, $gen-num );
        self."$mode"( $obj-key, $bytes);
    }

    method encrypt( $key, $dec --> Buf) {
        my Buf $iv .= new( (^256).pick xx KeyLen );
        my $enc = $iv;
        $enc.append: self!aes-encrypt($key, $dec, :$iv );
        $enc;
    }

    method decrypt( $key, $enc-iv) {
        my Buf $iv .= new: $enc-iv[^KeyLen];
        my @enc = +$enc-iv > KeyLen ?? $enc-iv[KeyLen .. *] !! [];
        self!aes-decrypt($key, Buf.new(@enc), :$iv );
    }

}
