role PDF::Object::DOM {

    use PDF::Object :from-ast;
    use PDF::Object::Tie::Hash;

    has Str $!Type;      method Type { self.tie($!Type) };
    has Str:_ $!Subtype; method Subtype { self.tie($!Subtype) };
    has Str:_ $!S;       method S { self.tie($!S) };

    BEGIN our @search-path = ();
    our %handler;

    method install-handler(Str $dom-class!) {
        @search-path.unshift( $dom-class )
            unless @search-path && @search-path[0] eq $dom-class;
        @search-path;
    }

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

    multi method find-delegate( :$pdf-class! where { %handler{$_}:exists } ) {
        %handler{$pdf-class}
    }

    multi method find-delegate( :$pdf-class! ) is default {

        my $handler-class = self.WHAT;
        my $resolved;

        for @search-path, 'PDF::Object::DOM' -> $dom-class {

            # autoload
            try {
                require ::($dom-class)::($pdf-class);
                $handler-class = ::($dom-class)::($pdf-class);
                $resolved = True;
                last;
            }

        }

        unless $resolved {
            warn "No DOM handler class in path @search-path[] PDF::Object::DOM: {$pdf-class}"
                if @search-path;
        }

        self.install-delegate( :$pdf-class, :$handler-class );
    }

    method delegate( Hash :$dict! ) {
        $dict<Type>
            ?? $.find-delegate( :type( from-ast($dict<Type>) ),
                                :subtype( from-ast($dict<Subtype> // $dict<S>) ) )
            !! self.WHAT;
    }

}
