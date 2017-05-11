use v6;

class X::PDF::Coerce
    is Exception {
	has $.obj is required;
	has $.role is required;
	method message {
	    "unable to coerce object $!obj of type {$!obj.WHAT.gist} to role {$!role.WHAT.gist}"
	}
}

class PDF::DAO::Delegator {

    use PDF::DAO;
    use PDF::DAO::Util :from-ast;

    use PDF::DAO::Array;
    use PDF::DAO::Tie::Array;

    use PDF::DAO::Dict;
    use PDF::DAO::Tie::Hash;

    use PDF::DAO::Name;
    use PDF::DAO::DateString;

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
    use PDF::DAO::TextString;
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
	$obj does $role;
        $obj.tie-init;
        $obj;
    }

    multi method coerce( Hash $obj where PDF::DAO, $role where PDF::DAO::Tie::Hash ) {
	$obj does $role;
        $obj.tie-init;
        $obj;
    }

    multi method coerce( $obj, $role where PDF::DAO::Tie ) {
	warn X::PDF::Coerce.new( :$obj, :$role );
        $obj;
    }

    my subset Role where { .does($_) && !.isa($_) };
    multi method coerce( $obj, Role $role)  {
        $obj does $role;
    }

    multi method coerce( $obj, $role) {
	warn X::PDF::Coerce.new( :$obj, :$role );
        $obj;
    }

    method class-paths { <PDF::DAO::Type> }

    our %handler;
    method handler {%handler}

    method install-delegate( Str $subclass, $class-def ) is rw {
        %handler{$subclass} = $class-def;
    }

    method find-delegate( Str $type!, $subtype?, :$fallback! ) is default {

	my $subclass = $type;
	$subclass ~= '::' ~ $_
	    with $subtype;

	return %handler{$subclass}
	    if %handler{$subclass}:exists;

	my $handler-class = $fallback;

	for self.class-paths -> \class-path {
            my \class-name = class-path ~ '::' ~ $subclass;
	    PDF::DAO.required(class-name);
	    $handler-class = ::(class-name);
	    last;
	    CATCH {
		when X::CompUnit::UnsatisfiedDependency { }
	    }
	}

	self.install-delegate( $subclass, $handler-class );
        $handler-class;
    }

    multi method delegate( Hash :$dict! where {$dict<Type>:exists}, :$fallback) {
	my \type = from-ast($dict<Type>);
	my \subtype = from-ast($dict<Subtype> // $dict<S>);
	$.find-delegate( type, subtype, :$fallback );
    }

    multi method delegate( :$fallback! ) is default {
	$fallback;
    }
}
