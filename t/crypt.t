use v6;
use Test;
use PDF::Storage::Crypt;

my Hash $Encrypt = {
   :V(2),
   :Filter<Standard>,
   :Length(128),
   :O("\xe6\x0\xec\xc2\x2\x88\xad\x8b\rd\xa9)\xc6\xa8>\xe2Qvy\xaa\x2\x18\xbe\xce\xea\x8by\x86rj\x8c\xdb"),
   :P(-3904),
   :R(3),
};

my Str $doc-id = "4\t\xc9\x89\x1b<}\xb8\x2lp\xb7\xfe-\x3\xe8";

my Hash $trailer = {
    :$Encrypt,
    :ID[$doc-id, $doc-id],
};

my $crypt-delegate = PDF::Storage::Crypt.delegate-class( :$trailer );

isa-ok $crypt-delegate, ::('PDF::Storage::Crypt::RC4'), '/V 2 crypt delegate';
do {
    temp $trailer<Encrypt><V> = 4;
    dies-ok {  PDF::Storage::Crypt.delegate-class( :$trailer ) }, '/V 4 -(unsupported)';
}

done-testing;
