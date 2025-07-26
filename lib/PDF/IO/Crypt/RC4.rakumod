use v6;

unit class PDF::IO::Crypt::RC4;

use PDF::IO::Crypt;
also is PDF::IO::Crypt;

use PDF::IO::Crypt::AST;
also does PDF::IO::Crypt::AST;

use PDF::IO::Util :pack;
use OpenSSL::Digest;

method type { 'V2' }

method !object-key(UInt $obj-num, UInt $gen-num ) {
    die "encryption has not been authenticated"
        unless $.key;

    my uint8 @obj-bytes = pack-le($obj-num, 32);
    my uint8 @gen-bytes = pack-le($gen-num, 32);
    my uint8 @obj-key = flat $.key.list, @obj-bytes[0 .. 2], @gen-bytes[0 .. 1];

    my UInt $size = +@obj-key;
    my Blob $key = md5( Buf.new: @obj-key );
    $key .= subbuf(0, $size)
        if $size < MD5_DIGEST_LENGTH;
    $key;
}

multi method crypt( Str $text, |c --> Str) {
    $.crypt( $text.encode("latin-1"), |c ).decode("latin-1");
}

multi method crypt( Blob $bytes, UInt :$obj-num!, UInt :$gen-num! --> Buf) {
    # Algorithm 3.1

    my Blob $obj-key = self!object-key( $obj-num, $gen-num );
    PDF::IO::Crypt.rc4-crypt( $obj-key, $bytes );
}

