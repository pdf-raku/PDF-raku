class X::PDF::Coerce
    is Exception {
	has $.obj is required;
	has $.type is required;
	method message {
	    "unable to coerce object {$!obj.perl} of type {$!obj.WHAT.^name} to {$!type.WHAT.^name}"
	}
}

class PDF::COS::Coercer {

    use PDF::COS;
    use PDF::COS::Util :from-ast;

    use PDF::COS::Array;
    use PDF::COS::Tie::Array;

    use PDF::COS::Dict;
    use PDF::COS::Tie::Hash;

    use PDF::COS::Name;
    use PDF::COS::DateString;
    use PDF::COS::ByteString;
    use PDF::COS::TextString;
    use PDF::COS::Bool;

    multi method coerce( $obj, $role where {$obj ~~ $role}) {
	# already does it
	$obj
    }

    # adds the DateTime 'object' rw accessor
    multi method coerce( Str $obj is rw, PDF::COS::DateString $class, |c) {
	$obj = $class.new( $obj, |c );
    }
    multi method coerce( DateTime $obj is rw, DateTime $class where PDF::COS, |c) {
	$obj = $class.new( $obj, |c );
    }
    multi method coerce( Str $obj is rw, PDF::COS::ByteString $class, Str :$type = $obj.?type // 'literal', |c) {
	$obj = $obj but PDF::COS::ByteString;
        $obj.type = $type;
        $obj;
    }
    multi method coerce( Str $obj is rw, PDF::COS::TextString $class, Str :$type = $obj.?type // 'literal', |c) {
	$obj = $class.new( :value($obj), :$type, |c );
    }
    multi method coerce( Bool $bool is rw, PDF::COS::Bool) {
	PDF::COS.coerce(:$bool);
    }

    # handle coercement to names or name subsets
    multi method coerce( PDF::COS::Name $obj, $role where PDF::COS::Name ) {
	$obj
    }

    multi method coerce( Str $obj is rw, $role where PDF::COS::Name ) {
	$obj = $obj but PDF::COS::Name
    }

    #| handle ro candidates for the above
    multi method coerce( Str $obj is copy, \r where PDF::COS::DateString|DateTime|PDF::COS::Name|PDF::COS::ByteString|PDF::COS::TextString|PDF::COS::Bool) {
	self.coerce( $obj, r);
    }

    multi method coerce( Array $obj is copy, PDF::COS::Array $class) {
        PDF::COS.coerce($obj);
    }

    multi method coerce( Array $obj is copy, PDF::COS::Tie::Array $role) {
        PDF::COS.coerce($obj).mixin: $role;
    }

    multi method coerce( Hash $obj is copy, PDF::COS::Dict $class) {
        PDF::COS.coerce($obj);
    }

    multi method coerce( Hash $obj is copy, PDF::COS::Tie::Hash $role) {
        PDF::COS.coerce($obj).mixin: $role;
    }

    multi method coerce( $obj, $type) {
	warn X::PDF::Coerce.new( :$obj, :$type );
        $obj;
    }

}
