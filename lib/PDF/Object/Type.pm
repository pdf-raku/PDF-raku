role PDF::Object::Type {

    use PDF::Object::Tie::Hash;

    has Str $!Type;      method Type { self.tie($!Type) };
    has Str:_ $!Subtype; method Subtype { self.tie($!Subtype) };
    has Str:_ $!S;       method S { self.tie($!S) };

}
