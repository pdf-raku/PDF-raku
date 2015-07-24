role PDF::Object::Type {

    use PDF::Object::Tie;

    has Str $!Type is tied;
    has Str $!Subtype is tied;
    has $!S is tied;

}
