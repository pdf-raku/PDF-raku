use v6;


class PDF::DAO::Loader {

    use PDF::DAO::Util :from-ast;

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
	    CATCH {
		when X::CompUnit::UnsatisfiedDependency { }
	    }
            my \class-name = class-path ~ '::' ~ $subclass;
	    $handler-class = PDF::DAO.required(class-name);
	    last;
	}

	self.install-delegate( $subclass, $handler-class );
        $handler-class;
    }

    multi method load-delegate( Hash :$dict! where {$dict<Type>:exists}, :$fallback = $dict.WHAT) {
	my \type = from-ast($dict<Type>);
	my \subtype = from-ast($dict<Subtype> // $dict<S>);
	$.find-delegate( type, subtype, :$fallback );
    }

    multi method load-delegate( :$fallback!, |c ) is default {
	$fallback;
    }

}
