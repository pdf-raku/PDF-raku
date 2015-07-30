role PDF::Object::Type {

    use PDF::Object::Tie;
    use PDF::Object::Name;

    has PDF::Object::Name $.Type is entry;
    has PDF::Object::Name $.Subtype is entry;
    has $.S is entry;

}
