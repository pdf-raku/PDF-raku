use v6;

use PDF::Object::Stream;

class PDF::Object::Type::Content
      is PDF::Object::Stream {

    #| avoid setting self<Type> = 'Content'
    multi method setup-type($) {}

}
