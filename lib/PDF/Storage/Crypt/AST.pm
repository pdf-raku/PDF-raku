use v6;

role PDF::Storage::Crypt::AST {

    #| encrypt/decrypt all strings/streams in a PDF body
    multi method crypt-ast('body', Array $body) {
	for $body.values {
	    $.crypt-ast(.key, .value)
		for .<objects>.values;
	}
    }

    #| descend and indirect object encrypting/decrypting any strings or streams
    multi method crypt-ast('ind-obj', Array $ast) {
	my UInt $obj-num = $ast[0];
	my UInt $gen-num = $ast[1];
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
	$ast = $.crypt( $ast, :$obj-num, :$gen-num, :$key )
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
