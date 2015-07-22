role PDF::Object::Type {

    use PDF::Object::Tie;

    has Str $!Type is tied;
    has Str:_ $!Subtype is tied;
    has Str:_ $!S is tied;

}
