role PDF::Tools::IndObj::Type {

    method Type is rw { %.dict<Type> }

    method find-subclass( Str $type-name ) {
        BEGIN constant KnownTypes = set <Catalog Font ObjStm Outlines Page Pages XRef>;

        if $type-name && (KnownTypes{ $type-name }:exists) {
            # autoload
            require ::("PDF::Tools::IndObj::Type")::($type-name);
            return ::("PDF::Tools::IndObj::Type")::($type-name);
        }
        else {
            # it has a /Type that we don't known about
            warn "unimplemented Indirect Stream Object: /Type /$type-name"
        }
    }

    method delegate-class( Hash :$dict! ) {

        my $type = $.find-subclass( $dict<Type>.value )
            if $dict<Type>:exists;

        $type.isa( self.WHAT )
            ?? $type
            !! self.WHAT;
    }

    #| enforce tie-ins between /Type, /Subtype & the class name. e.g.
    #| PDF::Tools::IndObj::Type::Catalog should have /Type = /Catalog
    method setup-type( Hash $dict is rw ) {
        for self.WHAT {
            my $class-name = .^name;
            warn $class-name;
            if $class-name ~~ /^ 'PDF::Tools::IndObj::Type::' (\w+) ['::' (\w+)]? $/ {
                my $type-name = ~$0;

                if $dict<Type>:!exists {
                    $dict<Type> = :name($type-name);
                }
                else {
                    # /Type already set. check it agrees with the class name
                    die "conflict between class-name $class-name ($type-name) and dictionary /Type /{$dict<Type>.value}"
                        unless $dict<Type>.value eq $type-name;
                }

                if $1 {
                    my $subtype-name = ~$1;

                    if $dict<Subtype>:!exists {
                        $dict<Subtype> = :name($subtype-name);
                    }
                    else {
                        # /Subtype already set. check it agrees with the class name
                        die "conflict between class-name $class-name ($subtype-name) and dictionary /Subtype /{$dict<Subtype>.value}"
                            unless $dict<Subtype>.value eq $subtype-name;
                    }
                }

                last;
            }
        }

    }

}
