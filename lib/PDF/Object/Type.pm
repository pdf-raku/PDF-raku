role PDF::Object::Type {

    use PDF::Object::Name;

    method Type is rw { self<Type> }

    method find-delegate( Str $type-name is copy, $subtype-name ) {
        BEGIN constant KnownTypes = set <Catalog Font ObjStm Outlines Page Pages XObject XRef>;
        BEGIN constant SubTypes = %(
            Font => set(<Type0 Type1 MMType1 Type3 TrueType CIDFontType0 CIDFontType2>),
            XObject => set(<Form Image>),
            );

        if $type-name {
            if ($type-name~'' ∈ KnownTypes) {
                $type-name ~= '::' ~ $subtype-name
                    if $subtype-name
                    && (SubTypes{$type-name}:exists)
                    && $subtype-name~'' ∈ SubTypes{$type-name};
                # autoload
                require ::("PDF::Object::Type")::($type-name);
                return ::("PDF::Object::Type")::($type-name);
            }
            else {
                # it has a /Type that we don't known about
                warn "unimplemented Indirect Stream Object: /Type /$type-name"
            }
        }

        self;
    }

    method delegate( Hash :$dict! ) {

        if $dict<Type>:exists {
            $.find-delegate( $dict<Type>, $dict<Subtype> // $dict<S> );
        }
        else {
            self;
        }
    }

    #| enforce tie-ins between /Type, /Subtype & the class name. e.g.
    #| PDF::Object::Type::Catalog should have /Type = /Catalog
    method setup-type( Hash $dict is rw ) {
        for self.^mro {
            my $class-name = .^name;

            if $class-name ~~ /^ 'PDF::Object::Type::' (\w+) ['::' (\w+)]? $/ {
                my $type-name = ~$0;

                if $dict<Type>:!exists {
                    $dict<Type> = $type-name but PDF::Object::Name;
                }
                else {
                    # /Type already set. check it agrees with the class name
                    die "conflict between class-name $class-name ($type-name) and dictionary /Type /{$dict<Type>}"
                        unless $dict<Type> eq $type-name;
                }

                if $1 {
                    my $subtype-name = ~$1;

                    if $dict<Subtype>:!exists {
                        $dict<Subtype> = $subtype-name but PDF::Object::Name;
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
