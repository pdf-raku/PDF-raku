use v6;

class PDF::Storage::Crypt {

    use PDF::DAO::Dict;
    use PDF::Storage::Util :resample;
    use PDF::DAO::Type::Encrypt;

    has UInt $.R;    #| encryption revision
    has Bool $.EncryptMetadata;
    has $.key is rw; #| encryption key
    has uint8 @.O;   #| computed owner password
    has UInt $.key-bytes; #| encryption key length
    has uint8 @.doc-id;
    has uint8 @.U;   #| computed user password
    has uint8 @.P;   #| permissions, unpacked as uint8
    has Bool $.is-owner is rw;

    # Taken from [PDF 1.7 Algorithm 3.2 - Standard Padding string]
     our @Padding is export(:Padding) = 
	0x28, 0xbf, 0x4e, 0x5e,
	0x4e, 0x75, 0x8a, 0x41,
	0x64, 0x00, 0x4e, 0x56,
	0xff, 0xfa, 0x01, 0x08,
	0x2e, 0x2e, 0x00, 0xb6,
	0xd0, 0x68, 0x3e, 0x80,
	0x2f, 0x0c, 0xa9, 0xfe,
	0x64, 0x53, 0x69, 0x7a;

    sub format-pass(Str $pass --> List) is export(:format-pass) {
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
                    UInt :$V = 2,
                    Bool :$!EncryptMetadata = False,
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
	my uint8 @p8 = resample([ $P, ], 32, 8).reverse;
	@!P = @p8;

        my uint8 @owner-pass = format-pass($owner-pass);
        my uint8 @user-pass = format-pass($user-pass);

	@!O = self.compute-owner( @owner-pass, @user-pass );

        @!U = self.compute-user( @user-pass, :$!key );
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
        $enc;
    }

    method load(PDF::DAO::Dict :$doc!) {
	my PDF::DAO::Type::Encrypt $encrypt = $doc<Encrypt>
	    or die "this document is not encrypted";

	die 'This PDF lacks an ID.  The document cannot be decrypted'
	    unless $doc<ID>;

	@!doc-id = $doc<ID>[0].ords;
	@!P =  resample([ $encrypt.P, ], 32, 8).reverse;
	$!R = $encrypt.R;
	$!EncryptMetadata = $encrypt.EncryptMetadata // False;
	@!O = $encrypt.O.ords;
	@!U = $encrypt.U.ords;

	my UInt $v = $encrypt.V;
	my Str $filter = $encrypt.Filter;

	die "Only Version 1 and 2 of the Standard encryption filter are supported"
	    unless $v == 1 | 2 && $filter eq 'Standard';

	my UInt $key-bits = $v == 1 ?? 40 !! $encrypt.Length // 40;
	die "invalid encryption key length: $key-bits"
	    unless 40 <= $key-bits <= 128
	    && $key-bits %% 8;

	$!key-bytes = $key-bits +> 3;
    }

    use Digest::MD5;
    my $digest-gcrypt-class;
    method digest-gcrypt-available {
	state Bool $have-it //= try {
	    require ::('Digest::GCrypt');
	    $digest-gcrypt-class = ::('Digest::GCrypt');
	    $digest-gcrypt-class.check-version;
	    True;
	} // False;
    }
	    
    multi method md5($msg) {
	$.digest-gcrypt-available
	    ?? Buf.new: $digest-gcrypt-class.md5($msg)
	    !! Digest::MD5.md5_buf(Buf.new($msg).decode('latin-1'));
    }

}
