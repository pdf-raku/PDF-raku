class X::PDF::Coerce
    is Exception {
	has $.obj is required;
	has $.type is required;
	method message {
	    "unable to coerce object {$!obj.raku} of type {$!obj.WHAT.^name} to {$!type.WHAT.^name}"
	}
}

class PDF::COS::Coercer {

    use PDF::COS;
    use PDF::COS::Tie::Array;
    use PDF::COS::Tie::Hash;
    use PDF::COS::ByteString;
    use PDF::COS::DateString;
    use PDF::COS::Null;
    use PDF::COS::TextString;
    our $warn;
    method coerce($a is raw, $b is raw) { self.coerce-to($a, $b) }

    # strip enumerations
    multi method coerce-to( Enumeration $_ is rw, PDF::COS $type) {
        $_ = $.coerce-to(.value, $type);
    }

    multi method coerce-to( Any:U $null is rw, $) {
	$null = PDF::COS::Null.new;
    }
    multi method coerce-to( Any:U $, $) {
	PDF::COS::Null.new;
    }

    multi method coerce-to( PDF::COS $obj is rw, PDF::COS $type, |c) {
        unless $obj ~~ $type {
            if $obj ~~ PDF::COS::ByteString && $type ~~ PDF::COS::TextString | PDF::COS::DateString {
                $obj = $type.COERCE: $obj, |c ;
            }
            elsif $warn {
	        warn X::PDF::Coerce.new: :$obj, :$type;
            }
        }
        $obj;
    }

    multi method coerce-to($obj is rw, PDF::COS $class, |c) {
	$obj = $class.COERCE( $obj, |c );
    }
    multi method coerce-to($obj, PDF::COS $class, |c) {
	$class.COERCE( $obj, |c );
    }

    multi method coerce-to( List:D $obj is copy, PDF::COS::Tie::Array $role) {
        PDF::COS.coerce($obj).mixin: $role;
    }

    multi method coerce-to( Hash:D $obj is copy, PDF::COS::Tie::Hash $role) {
        PDF::COS.coerce($obj).mixin: $role;
    }

    multi method coerce-to( Any:D $obj, $type) {
	warn X::PDF::Coerce.new( :$obj, :$type ) if $warn;
        $obj;
    }

}
