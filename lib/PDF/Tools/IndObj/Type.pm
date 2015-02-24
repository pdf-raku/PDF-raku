role PDF::Tools::IndObj::Type {

    method Type is rw { %.dict<Type> }

    method find-subclass( Str $type-name ) {
        BEGIN constant KnownTypes = set <Catalog ObjStm XRef>;

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

}
