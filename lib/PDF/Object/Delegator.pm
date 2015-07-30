use v6;

class PDF::Object::Delegator {

    use PDF::Object::Util :from-ast;

    method class-paths { <PDF::Object::Type> }

    our %handler;
    method handler {%handler}

    multi method install-delegate( :$type!, :$subtype, :$handler-class! ) {
        my Str $subclass = $subtype
            ?? [~] $type, '::', $subtype
            !! $type;
        self.install-delegate( :$subclass, :$handler-class );
    }

    multi method install-delegate( :$subclass!, :$handler-class ) {
        %handler{$subclass} = $handler-class;
    }

    multi method find-delegate( :$type!, :$subtype!, :$fallback!) {
        my Str $subclass = $subtype
            ?? [~] $type, '::', $subtype
            !! $type;
        self.find-delegate( :$subclass, :$fallback );
    }

    multi method find-delegate( :$subclass! where { self.handler{$_}:exists } ) {
        self.handler{$subclass}
    }

    multi method find-delegate( :$subclass!, :$fallback! ) is default {

	my $handler-class = $fallback;
	my Bool $resolved;

	for self.class-paths -> $class-path {
	    try {
		try { require ::($class-path)::($subclass) };
		$handler-class = ::($class-path)::($subclass);
		last;
	    };
	}

        self.install-delegate( :$subclass, :$handler-class );
    }

    multi method delegate( Hash :$dict! where {$dict<Type>:exists}, :$fallback) {
	my $type = from-ast($dict<Type>);
	my $subtype = from-ast($dict<Subtype> // $dict<S>);
	my $delegate = $.find-delegate( :$type, :$subtype, :$fallback );
	$delegate;
    }

    multi method delegate( :$fallback! ) is default {
	$fallback;
    }
}
