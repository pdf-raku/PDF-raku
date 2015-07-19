use v6;

role PDF::Object::Delegator {

    use PDF::Object::Util :from-ast;

    our %handler;

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

    multi method find-delegate( :$subclass! where { %handler{$_}:exists } ) {
        %handler{$subclass}
    }

    multi method find-delegate( :$subclass!, :$fallback! ) is default {

	my $handler-class = do given $subclass {
	    when 'XRef' | 'ObjStm' {
		require ::('PDF::Object::Type')::($subclass);
		::('PDF::Object::Type')::($subclass);
	    }
	    default {
		$fallback
	    }
	};

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
