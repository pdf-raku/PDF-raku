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

    multi method load( Hash :$dict! where {$dict<Type>:exists}, :$fallback) {
	my \type = from-ast($dict<Type>);
	my \subtype = from-ast($dict<Subtype> // $dict<S>);
	$.find-delegate( type, subtype, :$fallback );
    }

    multi method load( :$fallback! ) is default {
	$fallback;
    }
}
