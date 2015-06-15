use v6;

use PDF::Object;

role PDF::Object::Tie {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

    # coerce Hash & Array assignments to objects
    multi method coerce(PDF::Object $val!) { $val }
    multi method coerce(Hash $val!) {
        PDF::Object.compose( :dict($val), :$.reader )
    }
    multi method coerce(Array $val!) {
        PDF::Object.compose( :array($val), :$.reader )
    }
    multi method coerce($val) is default { $val }

    method lvalue($_) is rw {
        when PDF::Object  { $_ }
        when Hash | Array { $.coerce($_) }
        default           { $_ }
    }

    #| indirect reference
    multi method deref(Pair $ind-ref! where {.key eq 'ind-ref' && $.reader && $.reader.auto-deref}) {
        my $obj-num = $ind-ref.value[0];
        my $gen-num = $ind-ref.value[1];

        $.reader.ind-obj( $obj-num, $gen-num ).object;
    }
    #| already an object
    multi method deref(PDF::Object $value) { $value }

    #| simple native type. no need to coerce
    multi method deref($value) is default { $value }

    #| return a shallow unblessed/unauto-deref clone of a PDF::Object
    method raw() {

        return self
            if self !~~ Hash | Array
            || ! self.reader || ! self.reader.auto-deref;

        temp self.reader.auto-deref = False;

        my $raw;

        given self {
            when Hash {
                $raw := {};
                $raw{.key} = .value
                    for self.pairs;
            }
            when Array {
                $raw = [];
                $raw[.key] = .value
                    for self.pairs;
            }
        }
        $raw;
    }

}
