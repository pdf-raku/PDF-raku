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
            ?? $.deref(:$pos,$result )
            !! $result;
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref(:$key,$result)
            !! $result;
    }

    # coerce Hash & Array assignments to objects

    method ASSIGN-KEY($key, $val) {
        given $val {
            when PDF::Object { nextsame }
            when Hash {
                self.ASSIGN-KEY($key, PDF::Object.compose( :stream($val), :$.reader ) )
                    if $val<stream>:exists;
                self.ASSIGN-KEY($key, PDF::Object.compose( :dict($val), :$.reader ) );
            }
            when Array {
                self.ASSIGN-KEY($key, PDF::Object.compose( :array($val), :$.reader ) );
            }
            default { nextsame }
        }
    }

    method ASSIGN-POS($key, $val) {
        given $val {
            when PDF::Object { nextsame }
            when Hash {
                self.ASSIGN-POS($key, PDF::Object.compose( :stream($val), :$.reader ) )
                    if $val<stream>:exists;
                self.ASSIGN-POS($key, PDF::Object.compose( :dict($val), :$.reader ) );
            }
            when Array {
                self.ASSIGN-POS($key, PDF::Object.compose( :array($val), :$.reader ) );
            }
            default { nextsame }
        }
    }

    multi method deref(Pair $ind-ref! is rw) {
        return $ind-ref
            unless $ind-ref.key eq 'ind-ref' && $.reader;

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
    multi method deref($value) is default {
        $value
    }

}
