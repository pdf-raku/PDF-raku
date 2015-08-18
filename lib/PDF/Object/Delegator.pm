use v6;

class PDF::Object::Delegator {

    use PDF::Object::Util :from-ast;

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
