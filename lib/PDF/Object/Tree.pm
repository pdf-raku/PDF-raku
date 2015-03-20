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
    multi method coerce(PDF::Object $val!) { $val }
    multi method coerce(Hash $val!) {
        $val<stream>:exists
            ?? PDF::Object.compose( :stream($val), :$.reader )
            !! PDF::Object.compose( :dict($val), :$.reader )
    }
    multi method coerce(Array $val!) {
        PDF::Object.compose( :array($val), :$.reader )
    }
    multi method coerce($val) is default { $val }

    #| try to keep indirect references as such. avoids circular references.
    method !is-ind-ref($obj) {
        !! ( $.reader
             && $obj ~~ Hash | Array
             && $obj.obj-num
             && $.reader === $obj.reader );
    }

    method ASSIGN-KEY($key, $val) {
        given $val {
            when PDF::Object {
                self!"is-ind-ref"($val)
                    ?? nextwith($key, (:ind-ref[ $val.obj-num, $val.gen-num]) )
                    !! nextsame
            }
            when Hash | Array  {
                nextwith($key, $.coerce($val) );
            }
            default { nextsame }
        }
    }

    method ASSIGN-POS($pos, $val) {
        given $val {
            when PDF::Object {
                self!"is-ind-ref"($val)
                    ?? nextwith($pos, (:ind-ref[ $val.obj-num, $val.gen-num]) )
                    !! nextsame
            }
            when Hash | Array {
                nextwith($pos, $.coerce($val) );
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

    our %raw-ref;

    method raw() {
        die "illegal circular hash reference"
            if %raw-ref{self.WHICH};
        temp %raw-ref{self.WHICH} = True;

        given self {
            when Hash {
                my %raw;
                for self.pairs {
                    %raw{.key} = do given .value {
                        when PDF::Object && Array | Hash { .raw }
                        default { $_ }
                    }
                }
                %raw.item;
            }
            when Array {
                my @raw;
                for self.pairs {
                    @raw[.key] = do given .value {
                        when PDF::Object && Array | Hash { .raw }
                        default { $_ }
                    }
                }
                @raw.item;
            }
            default {
                self
            }
        }
    }

}
