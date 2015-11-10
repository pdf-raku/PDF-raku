use v6;

use PDF::DAO::Doc;
use PDF::Storage::Blob;
use PDF::Storage::Util :resample;
use Digest::MD5;
use Crypt::RC4;

class PDF::Storage::Crypt::RC4 {

    has UInt $!key-length;
    has $!code;
    has UInt @!doc-id;
    has UInt @!O;
    has UInt @!U;
    has UInt $!R;
    has UInt @!P;
    has Bool $!EncryptMetadata;

    BEGIN my uint8 @Padding = 
	0x28, 0xbf, 0x4e, 0x5e,
	0x4e, 0x75, 0x8a, 0x41,
	0x64, 0x00, 0x4e, 0x56,
	0xff, 0xfa, 0x01, 0x08,
	0x2e, 0x2e, 0x00, 0xb6,
	0xd0, 0x68, 0x3e, 0x80,
	0x2f, 0x0c, 0xa9, 0xfe,
	0x64, 0x53, 0x69, 0x7a;

    sub format-pass(Str $pass --> List) {
	my @pass-padded = flat $pass.NFKC.list, @Padding;
	@pass-padded[0..31];
    }

    method !do-iter-crypt($code, @pass is copy, :@steps = (1 ... 19)) {

	if $!R >= 3 {
	    for @steps -> $iter {
		my uint8 @key = $code.map({ $_ +^ $iter });
		@pass = Crypt::RC4::RC4(@key, @pass);
	    }
	}
	else {
	    @pass = Crypt::RC4::RC4($code, @pass);
	}
	@pass;
    }

    submethod BUILD(PDF::DAO::Doc :$doc!, Str :$user-pass = '', Str :$owner-pass = '') {
	my $encrypt = $doc.Encrypt
	    or die "this document is not encrypted";

	die 'This PDF lacks an ID.  The document cannot be decrypted'
	    unless $doc.ID;

	@!doc-id = $doc.ID[0].ords;
	@!O = $encrypt.O.ords;
	@!U = $encrypt.U.ords;
	my uint32 @p32 = $encrypt.P;
	my uint8 @p8 = resample(@p32, 32, 8).reverse;
	@!P = @p8;
	$!R = $encrypt.R;
	$!EncryptMetadata = $encrypt.EncryptMetadata // False;

	my UInt $v = $encrypt.V;
	my Str $filter = $encrypt.Filter;

	my @user  = format-pass( $user-pass );
	my @owner = format-pass( $owner-pass );

	die "Only Version 1 and 2 of the Standard encryption filter are supported"
	    unless $v == 1 | 2 && $filter eq 'Standard';

	my UInt $key-bits = $v == 1 ?? 40 !! $encrypt.Length // 40;
	die "invalid encryption key length: $key-bits"
	    unless 40 <= $key-bits <= 128
	    && $key-bits %% 8;


	$!key-length = $key-bits +> 3;
    }

    method !compute-user(@pass-padded) {
	# Algorithm 3.2
	my @input = flat @pass-padded,       # 1, 2
	                 @!O,                # 3
                         @!P,                # 4
                         @!doc-id;           # 5


	@input.append: 0xff xx 4             # 6
	    if $!R >= 4 && $!EncryptMetadata;

	my $key = Digest::MD5::md5(@input); # 7
	my $n = 5;

	if $!R >= 3 {                        # 8
	    $n = $!key-length;
	    for 1..50 {
		$key = $key.subbuf(0, $n)
		    unless +$key == $n;
		$key = Digest::MD5::md5($key);
	    }
	}

	$key;
    }

    method !auth-user-password(@pass) {
	# Algorithm 3.6
	my $key = self!compute-user( @pass )[0 .. 15];
	my $pass = [ @Padding.list ];
	my uint8 @computed;
	my uint8 @expected;

	if $!R >= 3 {
	    # Algorithm 3.5
	    $pass.append: @!doc-id;
	    $pass = Digest::MD5::md5( $pass );
	    $pass = Crypt::RC4::RC4($key, $pass);
	    $pass = self!do-iter-crypt($key, $pass.list);
	    $pass.append( @Padding[0 .. 15] );
	    @computed = $pass[0 .. 15];
	    @expected = @!U[0 .. 15];
	}
	else {
	    # Algorithm 3.4
	    $pass = Crypt::RC4::RC4($key, $pass);
	    @computed = @$pass;
	    @expected = @!U;
	}

	@computed eqv @expected
	    ?? $key
	    !! Nil
    }

    method !auth-owner-password(@) { ... }

    method authenticate(Str $pass, Bool :$owner) {
	my @pass = format-pass( $pass );
	$!code = (!$owner && self!auth-user-password( @pass ))
	    || self!auth-owner-password( @pass )
	    || die "unable to decrypt this PDF with the given password";
    }

}
