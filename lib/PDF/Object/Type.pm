role PDF::Object::Type {

    use PDF::Object :from-ast;
    use PDF::Object::Tie::Hash;

    has Str $!Type;      method Type { self.tie($!Type) };
    has Str:_ $!Subtype; method Subtype { self.tie($!Subtype) };
    has Str:_ $!S;       method S { self.tie($!S) };

    method classify( Hash :$dict! ) {
        $dict<Type>
            ?? $.find-delegate( :type( from-ast($dict<Type>) ),
                                :subtype( from-ast($dict<Subtype> // $dict<S>) ) )
            !! self.WHAT;
    }

}
