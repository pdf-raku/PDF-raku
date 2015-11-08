use v6;
use Test;
use PDF::Storage::Crypt;
use PDF::DAO::Doc;

my Hash $Encrypt = {
   :V(2),
   :Filter<Standard>,
   :Length(128),
   :O("\xe6\x0\xec\xc2\x2\x88\xad\x8b\rd\xa9)\xc6\xa8>\xe2Qvy\xaa\x2\x18\xbe\xce\xea\x8by\x86rj\x8c\xdb"),
   :U("\x90\xe3\x10\xf5\x3}\x88\xd4XG:^\n\fB8\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0\x0"),
   :P(-3904),
   :R(3),
};

my Str $doc-id = "4\t\xc9\x89\x1b<}\xb8\x2lp\xb7\xfe-\x3\xe8";

my $doc = PDF::DAO::Doc.new: {
    :$Encrypt,
    :ID[$doc-id, $doc-id],
};

my $crypt-delegate = PDF::Storage::Crypt.delegate-class( :$doc );
isa-ok $crypt-delegate, ::('PDF::Storage::Crypt::RC4'), '/V 2 crypt delegate';

my $crypt;
lives-ok { $crypt = $crypt-delegate.new( :$doc, :owner-pass<test> ) }, '$crypt.new (RC4, owner-pass)';
# hmm, I don't think CAM::PDF handles this either. Need to investigate
todo "blank user password";
lives-ok { $crypt = $crypt-delegate.new( :$doc ) }, '$crypt-new (RC4, blank user-pass)';

dies-ok { $crypt-delegate.new( :$doc, :owner-pass<junk>, :user-pass<junk> ) },  '$crypt-new (RC4, invalid passwords)';

do {
    temp $doc<Encrypt><V> = 3;
    dies-ok {  $crypt-delegate.new( :$doc ) }, '/V 3 (unsupported)';
}

done-testing;
