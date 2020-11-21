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

    use PDF::COS::Bool;
    use PDF::COS::ByteString;
    use PDF::COS::DateString;
    use PDF::COS::Name;
    use PDF::COS::Null;
    use PDF::COS::TextString;
    use PDF::COS::Real;

    method coerce($a is raw, $b is raw) { self.coerce-to($a, $b) }

    multi method coerce-to( PDF::COS $obj is rw, PDF::COS $type) {
	warn X::PDF::Coerce.new( :$obj, :$type )
            unless $obj ~~ $type;
        $obj;
    }

    # strip enumerations
    multi method coerce-to( Enumeration $_ is rw, PDF::COS $type) {
        $_ = $.coerce-to(.value, $type);
    }
    # adds the DateTime 'object' rw accessor
    multi method coerce-to(PDF::COS::ByteString $obj is rw, PDF::COS::DateString $class, |c) is default {
	$obj = $class.COERCE( $obj, |c );
    }
    multi method coerce-to($obj, PDF::COS::DateString $class, |c) is default {
	$class.COERCE( $obj, |c );
    }

    multi method coerce-to( Str:D() $obj is rw, PDF::COS::ByteString $class, |c) {
	$obj = $obj but PDF::COS::ByteString[$obj.?type // 'literal'];
    }
    multi method coerce-to( Str:D() $value is rw, PDF::COS::TextString $class, Str :$type = $value.?type // 'literal', |c) {
	$value = PDF::COS::TextString.new( :$value, :$type, |c );
    }
    multi method coerce-to( Bool:D() $bool is rw, PDF::COS::Bool) {
	$bool = PDF::COS.coerce(:$bool);
    }
    multi method coerce-to( Numeric:D $real is rw, PDF::COS::Real $role) {
	$real = $role.COERCE($real);
    }
    multi method coerce-to( Numeric:D $real, PDF::COS::Real $role) is default {
	$role.COERCE($real);
    }

    multi method coerce-to( Any:U $null is rw, $) {
	$null = PDF::COS::Null.new;
    }
    multi method coerce-to( Any:U $null, $) {
	PDF::COS::Null.new;
    }

    # handle coercement to names or name subsets

    multi method coerce-to( Str:D $obj is rw, $role where PDF::COS::Name ) {
	$obj = PDF::COS::Name.COERCE($obj);
    }

    #| handle ro candidates for the above
    multi method coerce-to( Str:D $obj is copy, \r where PDF::COS::DateString|Str|DateTime|PDF::COS::Name|PDF::COS::ByteString|PDF::COS::TextString|PDF::COS::Bool) {
	self.coerce-to( $obj, r);
    }

    multi method coerce-to( Array:D $obj is copy, PDF::COS::Array $class) {
        $obj = $class.COERCE($obj);
    }

    multi method coerce-to( Array:D $obj is copy, PDF::COS::Tie::Array $role) {
        PDF::COS.coerce($obj).mixin: $role;
    }

    multi method coerce-to( Hash:D $obj is copy, PDF::COS::Dict $class) {
        $class.COERCE($obj);
    }

    multi method coerce-to( Hash:D $obj is copy, PDF::COS::Tie::Hash $role) {
        PDF::COS.coerce($obj).mixin: $role;
    }

    multi method coerce-to( Any:D $obj, $type) {
	warn X::PDF::Coerce.new( :$obj, :$type );
        $obj;
    }

}
