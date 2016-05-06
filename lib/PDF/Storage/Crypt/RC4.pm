use v6;

use PDF::Storage::Crypt :Padding, :format-pass;

class PDF::Storage::Crypt::RC4
    is PDF::Storage::Crypt {

    use PDF::Storage::Blob;
    use PDF::Storage::Util :resample;
    use Crypt::RC4;

    method !do-iter-crypt($code, @pass is copy, :@steps = (1 ... 19)) {

	if $.R >= 3 {
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

    method compute-user(@pass-padded, :$key! is rw) {
	# Algorithm 3.2
	my uint8 @input = flat @pass-padded,       # 1, 2
	                       @.O,                # 3
                               @.P,                # 4
                               @.doc-id;           # 5


	@input.append: 0xff xx 4             # 6
	    if $.R >= 4 && ! $.EncryptMetadata;

	my UInt $n = 5;
	my UInt $reps = 1;

	if $.R >= 3 {                        # 8
	    $n = $.key-bytes;
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

	if $.R >= 3 {
	    # Algorithm 3.5 steps 1 .. 5
	    $pass.append: @.doc-id;
	    $pass = $.md5( $pass );
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
	my uint8 @computed = $.compute-user( @pass, :$key );
	my uint8 @expected = $.R >= 3
            ?? @.U[0 .. 15]
            !! @.U;

	@computed eqv @expected
	    ?? $key
	    !! Nil
    }

    method !compute-owner-key(@pass-padded) {
        # Algorithm 3.7 steps 1 .. 4
	my uint8 @input = @pass-padded;           # 1

	my UInt $n = 5;
	my UInt $reps = 1;

	if $.R >= 3 {                       # 3
	    $n = $.key-bytes;
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
        
	if $.R == 2 {      # 2 (Revision 2 only)
	    @owner = Crypt::RC4::RC4($key, @owner);
	}
	elsif $.R >= 3 {   # 2 (Revision 3 or greater)
	    @owner = self!do-iter-crypt($key, @owner, :steps(0..19) );
	}

        @owner;
    }

    method !auth-owner-pass(@pass) {
	# Algorithm 3.7
	my $key = self!compute-owner-key( @pass );    # 1
	my $user-pass = @.O.list;
	if $.R == 2 {      # 2 (Revision 2 only)
	    $user-pass = Crypt::RC4::RC4($key, $user-pass);
	}
	elsif $.R >= 3 {   # 2 (Revision 3 or greater)
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

    multi method crypt( Str $text, |c) {
	$.crypt( $text.encode("latin-1"), |c ).decode("latin-1");
    }

    multi method crypt( $bytes, UInt :$obj-num!, UInt :$gen-num! ) is default {
	# Algorithm 3.1

	die "encyption has not been authenticated"
	    unless $.key;

	my uint8 @obj-bytes = resample([ $obj-num, ], 32, 8).reverse;
	my uint8 @gen-bytes = resample([ $gen-num, ], 32, 8).reverse;
	my uint8 @obj-key = flat $.key.list, @obj-bytes[0 .. 2], @gen-bytes[0 .. 1];

	my UInt $size = +@obj-key;
	my $key = $.md5( @obj-key );
	$key = $key[0 ..^ $size]
	    if $size < 16;

	Crypt::RC4::RC4( $key, $bytes );
    }

}
