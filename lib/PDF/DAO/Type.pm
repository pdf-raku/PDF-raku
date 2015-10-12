role PDF::DAO::Type {

    use PDF::DAO::Tie;
    use PDF::DAO::Name;

    has PDF::DAO::Name $.Type is entry;
    has PDF::DAO::Name $.Subtype is entry;
    has $.S is entry;

}
