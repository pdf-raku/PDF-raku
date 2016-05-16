use v6;

class PDF::Storage::Crypt {

    use PDF::DAO::Dict;
    use PDF::Storage::Util :resample;
    use PDF::DAO::Type::Encrypt;
    use Crypt::RC4;

    has UInt $!R;         #| encryption revision
    has Bool $!EncryptMetadata;
    has $.key is rw;      #| encryption key
    has uint8 @!O;        #| computed owner password
    has UInt $!key-bytes; #| encryption key length
    has uint8 @.doc-id;   #| /ID entry in doucment root
    has uint8 @!U;        #| computed user password
    has uint8 @!P;        #| permissions, unpacked as uint8
    has Bool $.is-owner is rw; #| authenticated against, or created by, owner

    # Taken from [PDF 1.7 Algorithm 3.2 - Standard Padding string]
     our @Padding  = 
	0x28, 0xbf, 0x4e, 0x5e,
	0x4e, 0x75, 0x8a, 0x41,
	0x64, 0x00, 0x4e, 0x56,
	0xff, 0xfa, 0x01, 0x08,
	0x2e, 0x2e, 0x00, 0xb6,
	0xd0, 0x68, 0x3e, 0x80,
	0x2f, 0x0c, 0xa9, 0xfe,
	0x64, 0x53, 0x69, 0x7a;

    sub format-pass(Str $pass --> List) {
	my uint8 @pass-padded = flat $pass.NFKC.list, @Padding;
	@pass-padded[0..31];
    }

    submethod BUILD(:$doc!, Str :$owner-pass, |c) {
        $owner-pass
            ?? self.generate( :$doc, :$owner-pass, |c)
            !! self.load( :$doc, |c)
    }

    #| perform initial document encryption
    method generate(:$doc!,
                    Str  :$owner-pass!,
                    Str  :$user-pass = '',
                    UInt :$!R = 3,  #| revision (2 is faster)
                    UInt :$V = self.type eq 'AESV2' ?? 4 !! 2,
                    Bool :$!EncryptMetadata = True,
                    UInt :$Length = $V > 1 ?? 128 !! 40,
                    Int  :$P = -64,  #| permissions mask
                    --> PDF::DAO::Type::Encrypt
        ) {

        die "this document is already encrypted"
            if $doc.Encrypt;

	die "invalid encryption key length: $Length"
	    unless 40 <= $Length <= 128
            && ($V > 1 || $Length == 40)
	    && $Length %% 8;

	$!key-bytes = $Length +> 3;
	$doc.generate-id
	    unless $doc<ID>;

	@!doc-id = $doc<ID>[0].ords;
	my uint8 @p8 = resample([ $P ], 32, 8).reverse;
	@!P = @p8;

        my uint8 @owner-pass = format-pass($owner-pass);
        my uint8 @user-pass = format-pass($user-pass);

	@!O = self.compute-owner( @owner-pass, @user-pass );

        @!U = self.compute-user( @user-pass, :$!key );
        $!is-owner = True;

        my $O = hex-string => [~] @!O.map: *.chr;
        my $U = hex-string => [~] @!U.map: *.chr;

        my %dict = :$O, :$U, :$P, :$!R, :$V, :Filter<Standard>;

        if $V >= 4 {
            %dict<CF> = {
                :StdCF{
                    :CFM{ :name(self.type) },
                },
            };
            %dict<StmF> = :name<StdCF>;
            %dict<StrF> = :name<StdCF>;
        }

        %dict<Length> = $Length unless $V == 1;
        %dict<EncryptMetadata> = False
            if $!R >= 4 && ! $!EncryptMetadata;

        my $enc = $doc.Encrypt = %dict;

        # make it indirect. keep the trailer size to a minumum
        $enc.is-indirect = True;
        $enc;
    }

    method load(PDF::DAO::Dict :$doc!,
                UInt :$!R!,
                Bool :$!EncryptMetadata = True,
                UInt :$V!,
                Int  :$P!,
                Str  :$O!,
                Str  :$U!,
                UInt :$Length = 40,
                Str  :$Filter = 'Standard',
               ) {

	@!doc-id = $doc<ID>[0].ords;
	@!P =  resample([ $P ], 32, 8).reverse;
	@!O = $O.ords;
	@!U = $U.ords;

	die "Only the Standard encryption filter is supported"
	    unless $Filter eq 'Standard';

	my UInt $key-bits = $V == 1 ?? 40 !! $Length;
        $key-bits *= 8 if $key-bits <= 16;
	die "invalid encryption key length: $key-bits"
	    unless 40 <= $key-bits <= 128
	    && $key-bits %% 8;

	$!key-bytes = $key-bits +> 3;
    }

    use Digest::MD5;
    my $gcrypt-digest-class;
    method gcrypt-digest-available {
	state Bool $have-it //= try {
	    require ::('Crypt::GCrypt::Digest');
	    $gcrypt-digest-class = ::('Crypt::GCrypt::Digest');
	    $gcrypt-digest-class.check-version;
	    True;
	} // False;
    }
	    
    multi method md5($msg) {
	$.gcrypt-digest-available
	    ?? Buf.new: $gcrypt-digest-class.md5($msg)
	    !! Digest::MD5.md5_buf(Buf.new($msg).decode('latin-1'));
    }

    my $gcrypt-cipher-class;
    our sub gcrypt-cipher-available {
	state Bool $have-it //= try {
	    require ::('Crypt::GCrypt::Cipher');
	    $gcrypt-cipher-class = ::('Crypt::GCrypt::Cipher');
	    $gcrypt-cipher-class.check-version;
	    True;
	} // False;
    }
	    
    our sub rc4-crypt($key, $msg) {
        my @crypt = gcrypt-cipher-available()
            ?? $gcrypt-cipher-class.arcfour(:$key, $msg).list
            !! Crypt::RC4::RC4($key, $msg).list;
        @crypt;
    }

    sub aes-crypt($action, $msg, |c) {
        die "This encryption operation requires the Perl 6 Crypt::GCrypt module. Please install and try again."
	    unless gcrypt-cipher-available;
	$gcrypt-cipher-class.aes($msg, :$action, :mode<cbc>, |c)
    }
    method aes-encrypt($key, $msg, |c --> Buf) {
        aes-crypt('encrypt', $msg, :$key, |c);
    }
    method aes-decrypt($key, $msg, |c --> Buf) {
        aes-crypt('decrypt', $msg, :$key, |c);
    }

    method !do-iter-crypt($code, @pass is copy, :@steps = (1 ... 19)) {

	if $!R >= 3 {
	    for @steps -> $iter {
		my uint8 @key = $code.map({ $_ +^ $iter });
		@pass = rc4-crypt(@key, @pass);
	    }
	}
	else {
	    @pass = rc4-crypt($code, @pass);
	}
	@pass;
    }

    method compute-user(@pass-padded, :$key! is rw) {
	# Algorithm 3.2
	my uint8 @input = flat @pass-padded,       # 1, 2
	                       @!O,                # 3
                               @!P,                # 4
                               @.doc-id;           # 5


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
	    $key = $.md5($key);
	    $key = $key[0 ..^ $n]
		unless $key.elems <= $n;
	}

	my uint8 @computed;
	my $pass = [ @Padding.list ];

	if $!R >= 3 {
	    # Algorithm 3.5 steps 1 .. 5
	    $pass.append: @.doc-id;
	    $pass = $.md5( $pass );
	    $pass = rc4-crypt($key, $pass);
	    $pass = self!do-iter-crypt($key, $pass.list);
	    $pass.append( @Padding[0 .. 15] );
	    @computed = $pass[0 .. 15];
	}
	else {
	    # Algorithm 3.4
	    @computed = rc4-crypt($key, @Padding);
	}

        @computed;
    }

    method !auth-user-pass(@pass) {
	# Algorithm 3.6
        my $key;
	my uint8 @computed = $.compute-user( @pass, :$key );
	my uint8 @expected = $!R >= 3
            ?? @!U[0 .. 15]
            !! @!U;

	@computed eqv @expected
	    ?? $key
	    !! Nil
    }

    method !compute-owner-key(@pass-padded) {
        # Algorithm 3.7 steps 1 .. 4
	my uint8 @input = @pass-padded;           # 1

	my UInt $n = 5;
	my UInt $reps = 1;

	if $!R >= 3 {                       # 3
	    $n = $!key-bytes;
	    $reps = 51;
	}

	my $key = @input;

	for 1..$reps {
	    $key = $.md5($key);
	    $key = $key[0 ..^ $n]
		unless $key.elems <= $n;
	}

	$key;                               # 4
    }

    method compute-owner(@owner-pass, @user-pass) {
        # Algorithm 3.3
	my $key = self!compute-owner-key( @owner-pass );    # Steps 1..4

        my uint8 @owner = @user-pass;
        
	if $!R == 2 {      # 2 (Revision 2 only)
	    @owner = rc4-crypt($key, @owner);
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
	    $user-pass = rc4-crypt($key, $user-pass);
	}
	elsif $!R >= 3 {   # 2 (Revision 3 or greater)
	    $user-pass = self!do-iter-crypt($key, $user-pass, :steps(19, 18 ... 0) );
	}
	$.is-owner = True;
	self!auth-user-pass($user-pass.list);          # 3
    }

    method authenticate(Str $pass, Bool :$owner) {
	$.is-owner = False;
	my uint8 @pass = format-pass( $pass );
	self.key = (!$owner && self!auth-user-pass( @pass ))
	    || self!auth-owner-pass( @pass )
	    or die "unable to decrypt this PDF with the given password";
    }

}
