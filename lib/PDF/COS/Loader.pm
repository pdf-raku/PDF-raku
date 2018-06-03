use v6;


class PDF::COS::Loader {

    use PDF::COS::Util :from-ast;

    method class-paths { <PDF::COS::Type> }

    our %handler;
    method handler {%handler}
    method warn {False}

    method install-delegate( Str $subclass, $class-def ) is rw {
        %handler{$subclass} = $class-def;
    }

    method find-delegate( Str $type!, $subtype?, :$base-class! ) is default {

	my Str $subclass = $type;
	$subclass ~= '::' ~ $_
            with $subtype;

	return self.handler{$subclass}
	    if self.handler{$subclass}:exists;

        my $handler-class = $base-class;
        my Bool $resolved;

	for self.class-paths -> $class-path {
            my $class-name = $class-path ~ '::' ~ $subclass;
            $handler-class = PDF::COS.required($class-name);
            if $handler-class ~~ Failure {
                warn "failed to load: $class-name: {$handler-class.exception.message}";
            }
            else {
                $handler-class = $base-class.^mixin($handler-class)
                    unless $handler-class ~~ $base-class;
                $resolved = True;
                last;
            }
            CATCH {
                when X::CompUnit::UnsatisfiedDependency {
		    # try loading just the parent class
		    $handler-class = $.find-delegate($type, :$base-class)
			if $subtype;
		}
            }
	}

	note "No handler class {self.class-paths}::{$subclass}"
	    if !$resolved && $.warn;

        self.install-delegate( $subclass, $handler-class );
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
