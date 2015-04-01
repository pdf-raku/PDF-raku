use v6;

use PDF::Object;

role PDF::Object::Tree {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

    #| for array lookups, typically $foo[42]
    method AT-POS($pos) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref(:$pos, $result )
            !! $result;
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref(:$key, $result)
            !! $result;
    }

    # coerce Hash & Array assignments to objects
    multi method coerce(PDF::Object $val!) { $val }
    multi method coerce(Hash $val!) {
        PDF::Object.compose( :dict($val), :$.reader )
    }
    multi method coerce(Array $val!) {
        PDF::Object.compose( :array($val), :$.reader )
    }
    multi method coerce($val) is default { $val }

    method !lvalue($_) is rw {
        when PDF::Object  { $_ }
        when Hash | Array { $.coerce($_) }
        default           { $_ }
    }

    #| handle hash assignments: $foo<bar> = 42; $foo{$baz} := $x;
    method ASSIGN-KEY($key, $val) {
        my $lval = self!"lvalue"($val);
        nextwith( $key, $lval );
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val) {
        my $lval = self!"lvalue"($val);
        nextwith( $pos, $lval );
    }

    method push($val) {
        my $lval = self!"lvalue"($val);
        nextwith( $lval );
    }

    method unshift($val) {
        my $lval = self!"lvalue"($val);
        nextwith( $lval );
    }

    method splice($pos, $elems, *@replacement) {
        my @lvals = @replacement.map({ self!"lvalue"($_).item });
        nextwith( $pos, $elems, |@lvals);
    }

    #| indirect reference
    multi method deref(Pair $ind-ref! where {.key eq 'ind-ref' && $.reader && $.reader.auto-deref}) {
        my $obj-num = $ind-ref.value[0];
        my $gen-num = $ind-ref.value[1];

        $.reader.ind-obj( $obj-num, $gen-num ).object;
    }
    #| already an object
    multi method deref(PDF::Object $value) { $value }
    #| coerce and save hash entry
    multi method deref($value where Hash | Array , :$key!) {
        self.ASSIGN-KEY($key, $value);
    }
    #| coerce and save array entry
    multi method deref($value where Hash | Array , :$pos!) {
        self.ASSIGN-POS($pos, $value);
    }
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
