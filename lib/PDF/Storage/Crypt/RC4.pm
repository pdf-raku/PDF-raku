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
    has Int $!P;

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

    method !compute-hash(@pass) {
	my uint32 @p32 = ($!P);
	my uint8 @p8 = resample(@p32, 32, 8);
	my @input = @pass, @!O, @p8, @!doc-id;

	my $hash = Digest::MD5::md5(@input);

	if $!R == 3 {
	    for 1..50 {
		$hash = Digest::MD5::md5($hash);
	    }
	}

	my UInt $size = $!key-length +> 3;
	$hash.subbuf(0, $size);
    }

    method !do-iter-crypt($code, @pass is copy, Bool :$backward = False) {

	if $!R == 3 {
	    my @steps = $backward
		?? (19 ... 0)
		!! (0 ... 19);

	    my UInt $size = $!key-length +> 3;
	    for @steps -> $iter {
		my uint8 @xor-code = $code.map({ $_ +^ $iter });
		@pass = Crypt::RC4::RC4(@xor-code, @pass);
	    }
	}
	else {
	    @pass = Crypt::RC4::RC4($code, @pass);
	}
	@pass;
    }

    method !compute-owner( @u, @o) {

	my $buf = Digest::MD5::md5(@o);

	if $!R == 3 {
	    $buf = Digest::MD5::md5($buf)
		for 1 .. 50;
	}

	my UInt $size = $!key-length +> 3;
	my $code = $buf.subbuf(0, $size);

	self!do-iter-crypt($code, @u, :backward);
    }

    method !compute-user( @u, |c --> Array) {
	my $hash = self!compute-hash(@u);
	if $!R === 3 {
	    my @input = flat @Padding, @!doc-id[0 .. 15];
	    my $buf = Digest::MD5::md5(@input);
	    $buf = $buf.subbuf(0, 16);
	    my @code = self!do-iter-crypt($hash, $buf);
	    return @code;
	}
	else {
	    return Crypt::RC4::RC4($hash, @Padding);
	}
    }

    method !check-owner-pass( :@user!, :@owner! --> Bool) {
	my uint8 @computed = self!compute-owner( @user, @owner);
	my uint8 @expected = @!O;
	@computed eqv @expected;
    }

    method !check-user-pass( :@user! --> Bool) {
	my uint8 @computed = self!compute-user( @user );
	my uint8 @expected = @!O;
	@computed eqv @expected;
    }

    # adapted from CAM::PDF
    submethod BUILD(PDF::DAO::Doc :$doc!, Str :$user-pass = '', Str :$owner-pass = '') {
	my $encrypt = $doc.Encrypt
	    or die "this document is not encrypted";

	die 'This PDF lacks an ID.  The document cannot be decrypted'
	    unless $doc.ID;

	@!doc-id = $doc.ID[0].ords;
	@!O = $encrypt.O.ords;
	@!U = $encrypt.U.ords;
	$!P = $encrypt.P;
	$!R = $encrypt.R;

	my UInt $v = $encrypt.V;
	my Str $filter = $encrypt.Filter;

	my @user  = format-pass( $user-pass );
	my @owner = format-pass( $owner-pass );

	die "Only Version 1 and 2 of the Standard encryption filter are supported"
	    unless $v == 1 | 2 && $filter eq 'Standard';

	$!key-length = $v == 1
	    ?? 40
	    !! $encrypt.Length // 40;

	die "invalid encryption key length: $!key-length"
	    unless 40 <= $!key-length <= 128
	    && $!key-length %% 8;

	$!code = do {
	    when self!check-owner-pass( :@user, :@owner ) {
		self!compute-hash(@!O);
	    }
	    when self!check-user-pass( :@user ) {
		self!compute-hash(@!U);
	    }
	    default {
		die "unable to decrypt this PDF with given password(s)";
	    }
	}

    }

}
