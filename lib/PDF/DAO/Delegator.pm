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

    multi method coerce( Str $obj, $role where PDF::DAO::Name ) {
	$obj does PDF::DAO::Name
    }

    multi method coerce( Array $obj where PDF::DAO, $role where PDF::DAO::Tie::Array ) {
	$obj does $role;
	$obj.tie-init;
    }

    multi method coerce( Hash $obj where PDF::DAO, $role where PDF::DAO::Tie::Hash ) {
	$obj does $role;
	$obj.tie-init;
    }

    multi method coerce( $obj, $role where PDF::DAO::Tie ) {
	warn X::PDF::Coerce.new( :$obj, :$role );
    }

    multi method coerce( $obj, $role) is default {

	if $role.does($role) && !$role.isa($role) {
	    $obj does $role
	}
	else {
	    warn X::PDF::Coerce.new( :$obj, :$role );
	}
    }

    method class-paths { <PDF::DAO::Type> }

    our %handler;
    method handler {%handler}

    method install-delegate( Str $subclass, $class-def ) is rw {
        %handler{$subclass} = $class-def;
    }

    method find-delegate( Str $type!, $subtype?, :$fallback! ) is default {

	my $subclass = $type;
	$subclass ~= '::' ~ $subtype
	    if $subtype.defined;

	return %handler{$subclass}
	if %handler{$subclass}:exists;

	my $handler-class = $fallback;

	for self.class-paths -> $class-path {
	    require ::($class-path)::($subclass);
	    $handler-class = ::($class-path)::($subclass);
	    last;
	    CATCH {
		when X::CompUnit::UnsatisfiedDependency { }
	    }
	}

        self.install-delegate( $subclass, $handler-class );
    }

    multi method delegate( Hash :$dict! where {$dict<Type>:exists}, :$fallback) {
	my $type = from-ast($dict<Type>);
	my $subtype = from-ast($dict<Subtype> // $dict<S>);
	my $delegate = $.find-delegate( $type, $subtype, :$fallback );
	$delegate;
    }

    multi method delegate( :$fallback! ) is default {
	$fallback;
    }
}

=begin pod

This forms the basis for `PDF::DOM`'s extensive library of document object classes. It
includes classes and roles for object construction, validation and serialization.

- The `PDF::DAO` `coerce` methods should be used to create new Hash or Array based objects an appropriate sub-class will be chosen with the assistance of `PDF::DAO::Delegator`.

- The delegator may be subclassed. For example, the upstream module `PDF::DOM` subclasses `PDF::DAO::Delegator` with
`PDF::DOM::Delegator`.

=end pod
