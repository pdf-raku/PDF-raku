use v6;

class PDF::Storage::Crypt {

    method delegate-class( Hash :$doc! ) {
	return Nil
	    unless $doc<Encrypt>:exists;

	my $class = do given $doc<Encrypt><R> {
	    when 1..4 {
		require ::('PDF::Storage::Crypt::RC4');
		::('PDF::Storage::Crypt::RC4');
	    }
	    default {
		die "unsupported encryption version: $_";
	    }
	}
	$class;
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

    #| encrypt/decrypt all strings/streams in a PDF body
    multi method crypt-ast('body', Array $body) {
	for $body.values {
	    $.crypt-ast(.key, .value)
		for .<objects>.values;
	}
    }

    #| descend and indirect object encrypting/decrypting any strings or streams
    multi method crypt-ast('ind-obj', Array $ast) {
	my $obj-num = $ast[0];
	my $gen-num = $ast[1];
	$.crypt-ast( $ast[2], :$obj-num, :$gen-num );
    }

    multi method crypt-ast('array', Array $ast, |c) {
	$.crypt-ast($_, |c) for $ast.values;
    }

    multi method crypt-ast('dict', Hash $ast, |c) {
	$.crypt-ast($_, |c) for $ast.values;
    }

    multi method crypt-ast('stream', Hash $ast, |c) {
	$.crypt-ast($_, |c)
	    for $ast.pairs;
    }

    multi method crypt-ast(Str $key where 'hex-string' | 'literal' | 'encoded' , $ast is rw, :$obj-num, :$gen-num) {
	$ast = $.crypt( $ast, :$obj-num, :$gen-num )
	    if $obj-num
    }

    multi method crypt-ast( Pair $p, |c) { $.crypt-ast( $p.key, $p.value, |c) }

    #| for JSON deserialization, e.g. { :int(42) } => :int(42)
    use PDF::Grammar :AST-Types;
    multi method crypt-ast( Hash $h! where { .keys == 1 && .keys[0] ∈ AST-Types}, |c ) {
	my $p = $h.pairs[0];
        $.crypt-ast( $p.key, $p.value, |c )
    }

    multi method crypt-ast(Str $key, $) is default { }

}
