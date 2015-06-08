role PDF::DOM {

    use PDF::Object :from-ast;

    method Type is rw { self<Type> }
    method Subtype is rw { self<Subtype> }

    our %handler;

    multi method install-delegate( :$type!, :$subtype, :$handler-class! ) {
        my $pdf-class = $subtype
            ?? [~] $type, '::', $subtype
            !! $type;
        self.install-delegate( :$pdf-class, :$handler-class );
    }

    multi method install-delegate( :$pdf-class!, :$handler-class ) {
        %handler{$pdf-class} = $handler-class;
    }

    multi method find-delegate( :$type!, :$subtype!) {
        my $pdf-class = $subtype
            ?? [~] $type, '::', $subtype
            !! $type;
        self.find-delegate( :$pdf-class );
    }

    multi method find-delegate( :$pdf-class! where %handler{$_}:exists ) {
        %handler{$pdf-class}
    }

    multi method find-delegate( :$pdf-class! ) is default {

        my $dom-class = $pdf-class eq 'XRef' | 'ObjStm'
            ?? 'PDF::Object::Type'
            !! 'PDF::DOM';

        my $handler-class;
        {
            # autoload
            require ::($dom-class)::($pdf-class);
            $handler-class = ::($dom-class)::($pdf-class);

            CATCH {
                default {
                    warn "No handler class: $dom-class::$pdf-class";
                    $handler-class = self.WHAT;
                }
            }
        }

        self.install-delegate( :$pdf-class, :$handler-class );
    }

    method delegate( Hash :$dict! ) {
        $dict<Type>:exists
            ?? $.find-delegate( :type( from-ast($dict<Type>) ),
                                :subtype( from-ast($dict<Subtype> // $dict<S>) ) )
            !! self.WHAT;
    }

    #| enforce tie-ins between /Type, /Subtype & the class name. e.g.
    #| PDF::DOM::Catalog should have /Type = /Catalog
    method setup-type( Hash $dict is rw ) {
        for self.^mro {
            my $class-name = .^name;

            if $class-name ~~ /^ 'PDF::DOM::' (\w+) ['::' (\w+)]? $/ {
                my $type-name = ~$0;

                if $dict<Type>:!exists {
                    $dict<Type> = PDF::Object.compose( :name($type-name) );
                }
                else {
                    # /Type already set. check it agrees with the class name
                    die "conflict between class-name $class-name ($type-name) and dictionary /Type /{$dict<Type>}"
                        unless $dict<Type> eq $type-name;
                }

                if $1 {
                    my $subtype-name = ~$1;

                    if $dict<Subtype>:!exists {
                        $dict<Subtype> = PDF::Object.compose( :name($subtype-name) );
                    }
                    else {
                        # /Subtype already set. check it agrees with the class name
                        die "conflict between class-name $class-name ($subtype-name) and dictionary /Subtype /{$dict<Subtype>.value}"
                            unless $dict<Subtype> eq $subtype-name;
                    }
                }

                last;
            }
        }

    }

}
