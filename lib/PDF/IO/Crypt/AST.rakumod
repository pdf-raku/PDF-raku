use v6;

role PDF::IO::Crypt::AST {

    #| encrypt/decrypt all strings/streams in a PDF body
    multi method crypt-ast('body', Array $body, Str :$mode = 'decrypt') {
	for $body.values {
	    $.crypt-ast(.key, .value, :$mode)
		for .<objects>.values;
	}
    }

    #| descend and indirect object encrypting/decrypting any strings or streams
    multi method crypt-ast('ind-obj', Array $ast, |c) {
	my UInt $obj-num = $ast[0];
	my UInt $gen-num = $ast[1];
	$.crypt-ast( $ast[2], :$obj-num, :$gen-num, |c );
    }

    multi method crypt-ast('array', Array $ast, |c) {
	$.crypt-ast($_, |c) for $ast.values;
    }

    multi method crypt-ast('dict', Hash $ast, |c) {
	$.crypt-ast(.value, |c) for $ast.pairs.sort;
    }

    multi method crypt-ast('stream', Hash $ast, |c) {
	$.crypt-ast($_, |c)
	    for $ast.pairs;
        $ast<dict><Length> = %( :int(.codes) )
            with $ast<encoded>;
    }

    multi method crypt-ast(Str $key where 'hex-string'|'literal'|'encoded' , $ast is rw, :$obj-num, |c) {
	$ast = $.crypt( $ast, :$obj-num, |c )
	    if $obj-num
    }

    multi method crypt-ast( Pair $p, |c) { $.crypt-ast( $p.key, $p.value, |c) }

    #| for JSON deserialization, e.g. { :int(42) } => :int(42)
    use PDF::Grammar :AST-Types;
    BEGIN my %ast-types = AST-Types.enums;
    multi method crypt-ast( Hash $h! where { .keys == 1 && (%ast-types{.keys[0]}:exists)}, |c) {
        $.crypt-ast( |$h.kv, |c )
    }

    multi method crypt-ast(Str $key, $) { }
    multi method crypt-ast(Numeric) { }

}
