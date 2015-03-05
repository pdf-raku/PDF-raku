use v6;
use PDF::Object;

role PDF::Object::Name
    is PDF::Object {

    method content {
        :name(self~'')
    };
}

