role PDF::Object::Type {

    use PDF::Object::Tie;

    has Str $!Type is entry;
    has Str $!Subtype is entry;
    has $!S is entry;

}
