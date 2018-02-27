use v6;


class PDF::DAO::Loader {

    use PDF::DAO::Util :from-ast;

    method class-paths { <PDF::DAO::Type> }

    our %handler;
    method handler {%handler}

    method install-delegate( Str $subclass, $class-def ) is rw {
        %handler{$subclass} = $class-def;
    }

    method find-delegate( Str $type!, $subtype?, :$base-class! ) is default {

	my $subclass = $type;
	$subclass ~= '::' ~ $_
	    with $subtype;

	return %handler{$subclass}
	    if %handler{$subclass}:exists;

	my $handler-class = $base-class;

	for self.class-paths -> \class-path {
	    CATCH {
		when X::CompUnit::UnsatisfiedDependency { }
	    }
            my \class-name = class-path ~ '::' ~ $subclass;
	    $handler-class = PDF::DAO.required(class-name);
            $handler-class = $base-class.^mixin($handler-class)
                unless $handler-class.isa($base-class);
	    last;
	}

	self.install-delegate( $subclass, $handler-class );
        $handler-class;
    }

    multi method load-delegate( Hash :$dict! where {$dict<Type>:exists}, :$base-class = $dict.WHAT) {
	my \type = from-ast($dict<Type>);
	my \subtype = from-ast($dict<Subtype> // $dict<S>);
	$.find-delegate( type, subtype, :$base-class );
    }

    multi method load-delegate( :$base-class!, |c ) is default {
	$base-class;
    }

}
