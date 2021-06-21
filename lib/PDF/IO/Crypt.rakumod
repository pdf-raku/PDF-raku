use v6;

class PDF::IO::Crypt {

    use OpenSSL:ver(v0.1.4+);
    use OpenSSL::Digest;

    use PDF::COS::Dict;
    use PDF::IO::Util :pack;
    use PDF::COS::Type::Encrypt;

    has UInt $!revision;         #| encryption revision
    has Bool $!EncryptMetadata;
    has uint8 @!owner-pass;      #| computed owner password
    has UInt $!key-bytes;        #| encryption key length
    has uint8 @!doc-id;          #| /ID entry in document root
    has uint8 @user-pass;        #| computed user password
    has uint8 @!permissions;     #| permissions, unpacked as uint8
    has $.key is rw;             #| encryption key
    has Bool $.is-owner is rw;   #| authenticated against, or created by, owner

    # Taken from [PDF 32000 Algorithm 2: Standard Padding string]
     constant @Padding = array[uint8].new(
         0x28, 0xbf, 0x4e, 0x5e,
         0x4e, 0x75, 0x8a, 0x41,
         0x64, 0x00, 0x4e, 0x56,
         0xff, 0xfa, 0x01, 0x08,
         0x2e, 0x2e, 0x00, 0xb6,
         0xd0, 0x68, 0x3e, 0x80,
         0x2f, 0x0c, 0xa9, 0xfe,
         0x64, 0x53, 0x69, 0x7a,
       );

    sub format-pass(Str $pass) {
	my uint8 @pass-padded = flat $pass.NFKC.list, @Padding;
	@pass-padded[0..31];
    }

    submethod TWEAK(:$doc!, Str :$owner-pass, |c) {
        $owner-pass
            ?? self!generate( :$doc, :$owner-pass, |c)
            !! self!load( :$doc, |c)
    }

    #| perform initial document encryption
    method !generate(:$doc!,
                     Str  :$owner-pass!,
                     Str  :$user-pass = '',
                     UInt :R($!revision) = self.type eq 'AESV2' ?? 4 !! 3,
                     UInt :V($version) = self.type eq 'AESV2' ?? 4 !! 2,
                     Bool :$!EncryptMetadata = True,
                     UInt :$Length = $version > 1 ?? 128 !! 40,
                     Int  :P($permissions) = -64,  #| permissions mask
                     --> PDF::COS::Type::Encrypt
        ) {

        die "this document is already encrypted"
            if $doc.Encrypt;

	die "invalid encryption key length: $Length"
            unless 40 <= $Length <= 128
            && ($version > 1 || $Length == 40)
	    && $Length %% 8;

	$!key-bytes = $Length +> 3;
	$doc.generate-id
	    unless $doc<ID>;

	@!doc-id = $doc<ID>[0].ords;
	my uint8 @p8 = pack-le($permissions, 32);
	@!permissions = @p8;

        my uint8 @owner-pass = format-pass($owner-pass);
        my uint8 @user-pass = format-pass($user-pass);

	@!owner-pass = self.compute-owner( @owner-pass, @user-pass );
        @user-pass = self.compute-user( @user-pass, :$!key );
        $!is-owner = True;

        @user-pass.append: 0 xx 16
            if self.type eq 'AESV2';
        my $O = hex-string => [~] @!owner-pass».chr;
        my $U = hex-string => [~] @user-pass».chr;

        my %dict = :$O, :$U, :P($permissions), :R($!revision), :V($version), :Filter<Standard>;

        if $version >= 4 {
            %dict<CF> = {
                :StdCF{
                    :CFM{ :name(self.type) },
                },
            };
            %dict<StmF> = :name<StdCF>;
            %dict<StrF> = :name<StdCF>;
        }

        %dict<Length> = $Length unless $version == 1;
        %dict<EncryptMetadata> = False
            if $!revision >= 4 && ! $!EncryptMetadata;

        my $enc = $doc.Encrypt = %dict;

        # make it indirect. keep the trailer size to a minimum
        $enc.is-indirect = True;
        $enc;
    }

    method !load(PDF::COS::Dict :$doc!,
                 UInt :R($!revision)!,
                 Bool :$!EncryptMetadata = True,
                 UInt :V($version)!,
                 Int  :P($permissions)!,
                 Str  :O($owner-pass)!,
                 Str  :U($user-pass)!,
                 UInt :$Length = 40,
                 Str  :$Filter = 'Standard',
                ) {

        with $doc<ID>[0] {
	    @!doc-id = .ords;
        }
        else {
            die 'This PDF lacks an ID.  The document cannot be decrypted'
        }
	@!permissions = pack-le($permissions, 32);
	@!owner-pass = $owner-pass.ords;
	@user-pass = $user-pass.ords;

	die "Only the Standard encryption filter is supported"
	    unless $Filter eq 'Standard';

	my uint $key-bits = $version == 1 ?? 40 !! $Length;
        $key-bits *= 8 if $key-bits <= 16;  # assume bytes
	die "invalid encryption key length: $key-bits"
	    unless 40 <= $key-bits <= 128
	    && $key-bits %% 8;

	$!key-bytes = $key-bits +> 3;
    }

    use OpenSSL::NativeLib;
    use NativeCall;

    sub RC4_set_key(Blob, int32, Blob) is native(&gen-lib) { ... }
    sub RC4(Blob, int32, Blob, Blob) is native(&gen-lib) { ... }

    method rc4-crypt(Blob $key, Blob $in) {
        # from openssl/rc4.h:
        # typedef struct rc4_key_st {
        #   RC4_INT x, y;
        #   RC4_INT data[256];
        # } RC4_KEY;

        constant RC4_INT = uint32;
        my \rc4 = Buf[RC4_INT].allocate(258);
        RC4_set_key(rc4, $key.bytes, $key);
        my buf8 $out .= allocate($in.bytes);
        RC4(rc4, $in.bytes, $in, $out);
        $out;
    }

    method !do-iter-crypt(Blob $code, @pass, $n=0, $m=19) {
        my Buf $crypt .= new: @pass;
	for $n ... $m -> \iter {
	    my Buf $key .= new: $code.map( * +^ iter );
	    $crypt = $.rc4-crypt($key, $crypt);
	}
	$crypt;
    }

    method compute-user(@pass-padded, :$key! is rw) {
	# Algorithm 3.2
	my uint8 @input = flat @pass-padded,       # 1, 2
	                       @!owner-pass,                # 3
                               @!permissions,                # 4
                               @!doc-id;           # 5


	@input.append: 0xff xx 4             # 6
	    if $!revision >= 4 && ! $!EncryptMetadata;

	my uint $n = 5;
	my uint $reps = 1;

	if $!revision >= 3 {                        # 8
	    $n = $!key-bytes;
	    $reps = 51;
	}

	$key = Buf.new: @input;

	for 1 .. $reps {
	    $key = md5($key);
	    $key.reallocate($n)
		unless $key.elems <= $n;
	}

	my Buf $pass .= new: @Padding;

	my uint8 @computed = do if $!revision >= 3 {
	    # Algorithm 3.5 steps 1 .. 5
	    $pass.append: @!doc-id;
	    $pass = md5( $pass );
	    self!do-iter-crypt($key, $pass);
	}
	else {
	    # Algorithm 3.4
	    $.rc4-crypt($key, $pass);
	}

        @computed;
    }

    method !auth-user-pass(@pass) {
	# Algorithm 3.6
        my $key;
	my uint8 @computed := $.compute-user( @pass, :$key );
	my uint8 @expected = $!revision >= 3
            ?? @user-pass[0 .. 15]
            !! @user-pass;

	@computed eqv @expected
	    ?? $key
	    !! Nil
    }

    method !compute-owner-key(@pass-padded) {
        # Algorithm 3.7 steps 1 .. 4
	my Buf $key .= new: @pass-padded;   # 1

	my uint $n = 5;
	my uint $reps = 1;

	if $!revision >= 3 {                       # 3
	    $n = $!key-bytes;
	    $reps = 51;
	}

	for 1..$reps {
	    $key = md5($key);
	    $key.reallocate($n)
		unless $key.elems <= $n;
	}

	$key;                               # 4
    }

    method compute-owner(@owner-pass, @user-pass) {
        # Algorithm 3.3
	my Buf \key = self!compute-owner-key( @owner-pass );    # Steps 1..4

        my Buf $user .= new: @user-pass;

	my uint8 @owner = do if $!revision == 2 {      # 2 (Revision 2 only)
	    $.rc4-crypt(key, $user);
	}
	elsif $!revision >= 3 {   # 2 (Revision 3 or greater)
	    self!do-iter-crypt(key, $user);
	}

        @owner;
    }

    method !auth-owner-pass(@pass) {
	# Algorithm 3.7
	my Buf \key = self!compute-owner-key( @pass );    # 1
	my Buf $user-pass .= new: @!owner-pass;
	if $!revision == 2 {      # 2 (Revision 2 only)
	    $user-pass = $.rc4-crypt(key, $user-pass);
	}
	elsif $!revision >= 3 {   # 2 (Revision 3 or greater)
	    $user-pass = self!do-iter-crypt(key, $user-pass, 19, 0);
	}
	$.is-owner = True;
	self!auth-user-pass($user-pass.list);          # 3
    }

    method authenticate(Str $pass, Bool :$owner) is hidden-from-backtrace {
	$.is-owner = False;
	my uint8 @pass = format-pass( $pass );
	self.key = (!$owner && self!auth-user-pass( @pass ))
	    || self!auth-owner-pass( @pass )
	    or die "unable to decrypt this PDF with the given password";
    }

}
