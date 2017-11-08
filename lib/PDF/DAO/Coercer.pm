class X::PDF::Coerce
    is Exception {
	has $.obj is required;
	has $.type is required;
	method message {
	    "unable to coerce object $!obj of type {$!obj.WHAT.gist} to {$!type.WHAT.gist}"
	}
}

class PDF::DAO::Coercer {

    use PDF::DAO;
    use PDF::DAO::Util :from-ast;

    use PDF::DAO::Array;
    use PDF::DAO::Tie::Array;

    use PDF::DAO::Dict;
    use PDF::DAO::Tie::Hash;

    use PDF::DAO::Name;
    use PDF::DAO::DateString;
    use PDF::DAO::TextString;

    multi method coerce( $obj, $role where {$obj ~~ $role}) {
	# already does it
	$obj
    }

    # adds the DateTime 'object' rw accessor
    multi method coerce( Str $obj is rw, PDF::DAO::DateString $class, |c) {
	$obj = $class.new( $obj, |c );
    }
    multi method coerce( DateTime $obj is rw, DateTime $class where PDF::DAO, |c) {
	$obj = $class.new( $obj, |c );
    }
    multi method coerce( Str $obj is rw, PDF::DAO::TextString $class, Str :$type is copy, |c) {
	$type //= $obj.?type // 'literal';
	$obj = $class.new( :value($obj), :$type, |c );
    }

    multi method coerce( Str $obj is rw, $role where PDF::DAO::Name ) {
	$obj = $obj but PDF::DAO::Name
    }

    #| handle ro candidates for the above
    multi method coerce( Str $obj is copy, \r where PDF::DAO::DateString|DateTime|PDF::DAO::Name) {
	self.coerce( $obj, r);
    }

    multi method coerce( Array $obj where PDF::DAO, $role where PDF::DAO::Tie::Array ) {
	$obj.^mixin: $role;
        $obj.tie-init;
        $obj;
    }

    multi method coerce( Hash $obj where PDF::DAO, $role where PDF::DAO::Tie::Hash ) {
	$obj.^mixin: $role;
        $obj.tie-init;
        $obj;
    }

    multi method coerce( $obj, $type where PDF::DAO::Tie ) {
	warn X::PDF::Coerce.new( :$obj, :$type );
        $obj;
    }

    my subset Role where { .does($_) && !.isa($_) };
    multi method coerce( $obj, Role $role)  {
        $obj.^mixin: $role;
    }

    multi method coerce( $obj, $type) {
	warn X::PDF::Coerce.new( :$obj, :$type );
        $obj;
    }

}
