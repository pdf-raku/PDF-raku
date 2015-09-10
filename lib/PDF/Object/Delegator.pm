use v6;

class PDF::Object::Delegator {

    use PDF::Object;
    use PDF::Object::Util :from-ast;

    use PDF::Object::Array;
    use PDF::Object::Tie::Array;

    use PDF::Object::Dict;
    use PDF::Object::Tie::Hash;

    multi method coerce( $obj, $role where {$obj ~~ $role}) {
	# already does it
	$obj
    }

    multi method coerce( PDF::Object::Dict $obj, PDF::Object::Tie::Hash $role) {
	$obj does $role; $obj.?tie-init;
    }

    multi method coerce( PDF::Object::Array $obj, PDF::Object::Tie::Array $role) {
	$obj does $role; $obj.?tie-init;
    }

    # adds the DateTime 'object' rw accessor
    use PDF::Object::DateString;
    multi method coerce( Str $obj is rw, PDF::Object::DateString $class, |c) {
	$obj = $class.new( $obj, |c );
    }
    multi method coerce( DateTime $obj is rw, DateTime $class where PDF::Object, |c) {
	$obj = $class.new( $obj, |c );
    }

    multi method coerce( $obj, $role) is default {
	die "unable to coerce object $obj of type {$obj.WHAT.gist} to role {$role.WHAT.gist}"
    }

    method class-paths { <PDF::Object::Type> }

    our %handler;
    method handler {%handler}

    method install-delegate( Str $subclass, $class-def ) is rw {
        %handler{$subclass} = $class-def;
    }

    multi method find-delegate( Str $subclass! where { %handler{$_}:exists } ) {
        %handler{$subclass}
    }

    multi method find-delegate( Str $subclass!, :$fallback! ) is default {

	my $handler-class = $fallback;

	for self.class-paths -> $class-path {
	    try {
		try { require ::($class-path)::($subclass) };
		$handler-class = ::($class-path)::($subclass);
		last;
	    };
	}

        self.install-delegate( $subclass, $handler-class );
    }

    multi method delegate( Hash :$dict! where {$dict<Type>:exists}, :$fallback) {
	my $subclass = from-ast($dict<Type>);
	my $subtype = from-ast($dict<Subtype> // $dict<S>);
	$subclass ~= '::' ~ $subtype if $subtype.defined;
	my $delegate = $.find-delegate( $subclass, :$fallback );
	$delegate;
    }

    multi method delegate( :$fallback! ) is default {
	$fallback;
    }
}
