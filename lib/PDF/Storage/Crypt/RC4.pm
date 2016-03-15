use v6;

use PDF::Storage::Crypt;

class PDF::Storage::Crypt::RC4
    is PDF::Storage::Crypt {

    use PDF::DAO::Dict;
    use PDF::Storage::Blob;
    use PDF::Storage::Util :resample;
    use Digest::MD5;
    use Crypt::RC4;

    has $!key;     #| encryption key
    has UInt $!key-bytes; #| encryption key length
    has UInt @!doc-id;
    has UInt @!O;  #| computed owner password
    has UInt @!U;  #| computed user password
    has UInt $!R;  #| encryption revision
    has UInt @!P;  #| permissions, unpacked as uint8
    has Bool $!EncryptMetadata;
    has Bool $.is-owner is rw;

    # Taken from [PDF 1.7 Algorithm 3.2 - Standard Padding string]
    BEGIN my uint8 @Padding = 
	0x28, 0xbf, 0x4e, 0x5e,
	0x4e, 0x75, 0x8a, 0x41,
	0x64, 0x00, 0x4e, 0x56,
	0xff, 0xfa, 0x01, 0x08,
	0x2e, 0x2e, 0x00, 0xb6,
	0xd0, 0x68, 0x3e, 0x80,
	0x2f, 0x0c, 0xa9, 0xfe,
	0x64, 0x53, 0x69, 0x7a;

    submethod BUILD(:$doc!, Str :$owner-pass, |c) {
        $owner-pass
            ?? self.generate( :$doc, :$owner-pass, |c)
            !! self.load( :$doc, |c)
    }

    #| perform initial document encryption
    submethod generate(:$doc!,
                       Str  :$owner-pass!,
                       Str  :$user-pass = '',
                       UInt :$!R = 3,  #| revision (2 is faster)
                       UInt :$V = 2,
                       Bool :$!EncryptMetadata = False,
                       UInt :$Length = $V > 1 ?? 128 !! 40,
                       Int  :$P = -64,  #| permissions mask
        ) {

        die "this document is already encrypted"
            if $doc.Encrypt;

	die "invalid encryption key length: $Length"
	    unless 40 <= $Length <= 128
            && ($V > 1 || $Length == 40)
	    && $Length %% 8;

	$!key-bytes = $Length +> 3;

	$doc.generate-id
	    unless $doc.ID;

	@!doc-id = $doc.ID[0].ords;
	my uint8 @p8 = resample([ $P, ], 32, 8).reverse;
	@!P = @p8;

        my @owner-pass = format-pass($owner-pass);
        my @user-pass = format-pass($user-pass);

	@!O = self!compute-owner( @owner-pass, @user-pass );

        @!U = self!compute-user( @user-pass, :$!key );
        $!is-owner = True;

        my $O = hex-string => [~] @!O.map: *.chr;
        my $U = hex-string => [~] @!U.map: *.chr;

        my %dict = :$O, :$U, :$P, :$!R, :$V, :Filter<Standard>;

        %dict<Length> = $Length unless $V == 1;
        %dict<EncryptMetadata> = True
            if $!R >= 4 && $!EncryptMetadata;

        my $enc = $doc.Encrypt = %dict;

        # make it indirect. keep the trailer size to a minumum
        $enc.is-indirect = True;
    }

    #| open a previously encrypted document
    submethod load(PDF::DAO::Dict :$doc!) is default {
	my $encrypt = $doc<Encrypt>
	    or die "this document is not encrypted";

	die 'This PDF lacks an ID.  The document cannot be decrypted'
	    unless $doc<ID>;

	@!doc-id = $doc<ID>[0].ords;
	my uint8 @p8 = resample([ $encrypt<P>, ], 32, 8).reverse;
	@!P = @p8;
	$!R = $encrypt<R>;
	$!EncryptMetadata = $encrypt<EncryptMetadata> // False;
	@!O = $encrypt<O>.ords;
	@!U = $encrypt<U>.ords;

	my UInt $v = $encrypt<V>;
	my Str $filter = $encrypt<Filter>;

	die "Only Version 1 and 2 of the Standard encryption filter are supported"
	    unless $v == 1 | 2 && $filter eq 'Standard';

	my UInt $key-bits = $v == 1 ?? 40 !! $encrypt<Length> // 40;
	die "invalid encryption key length: $key-bits"
	    unless 40 <= $key-bits <= 128
	    && $key-bits %% 8;

	$!key-bytes = $key-bits +> 3;
    }

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

    method !compute-user(@pass-padded, :$key! is rw) {
	# Algorithm 3.2
	my @input = flat @pass-padded,       # 1, 2
	                 @!O,                # 3
                         @!P,                # 4
                         @!doc-id;           # 5


	@input.append: 0xff xx 4             # 6
	    if $!R >= 4 && ! $!EncryptMetadata;

	my UInt $n = 5;
	my UInt $reps = 1;

	if $!R >= 3 {                        # 8
	    $n = $!key-bytes;
	    $reps = 51;
	}

	$key = @input;

	for 1 .. $reps {
	    $key = Digest::MD5::md5($key);
	    $key = $key.subbuf(0, $n)
		unless +$key <= $n;
	}

	my uint8 @computed;
	my $pass = [ @Padding.list ];

	if $!R >= 3 {
	    # Algorithm 3.5 steps 1 .. 5
	    $pass.append: @!doc-id;
	    $pass = Digest::MD5::md5( $pass );
	    $pass = Crypt::RC4::RC4($key, $pass);
	    $pass = self!do-iter-crypt($key, $pass.list);
	    $pass.append( @Padding[0 .. 15] );
	    @computed = $pass[0 .. 15];
	}
	else {
	    # Algorithm 3.4
	    @computed = Crypt::RC4::RC4($key, @Padding);
	}

        @computed;
    }

    method !auth-user-pass(@pass) {
	# Algorithm 3.6
        my $key;
	my uint8 @computed = self!compute-user( @pass, :$key );
	my uint8 @expected = $!R >= 3
            ?? @!U[0 .. 15]
            !! @!U;

	@computed eqv @expected
	    ?? $key
	    !! Nil
    }

    method !compute-owner-key(@pass-padded) {
        # Algorithm 3.7 steps 1 .. 4
	my @input = @pass-padded;           # 1

	my UInt $n = 5;
	my UInt $reps = 1;

	if $!R >= 3 {                       # 3
	    $n = $!key-bytes;
	    $reps = 51;
	}

	my $key = @input;

	for 1..$reps {
	    $key = Digest::MD5::md5($key);
	    $key = $key.subbuf(0, $n)
		unless +$key <= $n;
	}

	$key;                               # 4
    }

    method !compute-owner(@owner-pass, @user-pass) {
        # Algorithm 3.3
	my $key = self!compute-owner-key( @owner-pass );    # Steps 1..4

        my @owner = @user-pass;
        
	if $!R == 2 {      # 2 (Revision 2 only)
	    @owner = Crypt::RC4::RC4($key, @owner);
	}
	elsif $!R >= 3 {   # 2 (Revision 3 or greater)
	    @owner = self!do-iter-crypt($key, @owner, :steps(0..19) );
	}

        @owner;
    }

    method !auth-owner-pass(@pass) {
	# Algorithm 3.7
	my $key = self!compute-owner-key( @pass );    # 1
	my $user-pass = @!O.list;
	if $!R == 2 {      # 2 (Revision 2 only)
	    $user-pass = Crypt::RC4::RC4($key, $user-pass);
	}
	elsif $!R >= 3 {   # 2 (Revision 3 or greater)
	    $user-pass = self!do-iter-crypt($key, $user-pass, :steps(19, 18 ... 0) );
	}
	$!is-owner = True;
	self!auth-user-pass($user-pass.list);          # 3
    }

    method authenticate(Str $pass, Bool :$owner) {
	$!is-owner = False;
	my @pass = format-pass( $pass );
	$!key = (!$owner && self!auth-user-pass( @pass ))
	    || self!auth-owner-pass( @pass )
	    || die "unable to decrypt this PDF with the given password";
    }

    multi method crypt( Str $text, |c) {
	$.crypt( $text.encode("latin-1"), |c ).decode("latin-1");
    }

    multi method crypt( $bytes, UInt :$obj-num!, UInt :$gen-num! ) is default {
	# Algorithm 3.1

	die "encyption has not been authenticated"
	    unless $!key;

	my uint8 @obj-bytes = resample([ $obj-num, ], 32, 8).reverse;
	my uint8 @gen-bytes = resample([ $gen-num, ], 32, 8).reverse;
	my uint8 @obj-key = flat $!key.list, @obj-bytes[0 .. 2], @gen-bytes[0 .. 1];

	my UInt $size = +@obj-key;
	my $key = Digest::MD5::md5( @obj-key );
	$key = $key.subbuf(0, $size)
	    if $size < 16;

	Crypt::RC4::RC4( $key, $bytes );
    }

}
