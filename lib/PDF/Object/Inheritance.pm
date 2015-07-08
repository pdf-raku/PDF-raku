use v6;

role PDF::Object::Inheritance {

    #| find an heritable property
    proto method find-prop(|) {*}
    multi method find-prop($prop where { self{$_}:exists }) {
        self{$prop}
    }
    multi method find-prop($prop where { self<Parent>:exists }) {
        self<Parent>.can('find-prop')
            ?? self<Parent>.find-prop($prop)
            !! self<Parent>{$prop}
    }
    multi method find-prop($prop) is default {
    }

}
