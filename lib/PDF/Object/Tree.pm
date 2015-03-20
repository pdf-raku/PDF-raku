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

    #| try to keep indirect references as such. avoids circular references.
    method !is-ind-ref($obj) {
        if self.reader
            && $obj ~~ Hash | Array && $obj.obj-num
            && self.reader === $obj.reader {
                my $ind-obj = self.reader.ind-obj($obj.obj-num, $obj.gen-num);
                return $ind-obj && $ind-obj.object === $obj;
        }
        False;
    }

    # coerce Hash & Array assignments to objects

    method ASSIGN-KEY($key, $val) {
        given $val {
            when PDF::Object {
                self!"is-ind-ref"($val)
                    ?? self.ASSIGN-KEY($key, (:ind-ref[ $val.obj-num, $val.gen-num]) )
                    !! nextsame
            }
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

    method ASSIGN-POS($pos, $val) {
        given $val {
            when PDF::Object {
                self!"is-ind-ref"($val)
                    ?? self.ASSIGN-POS($pos, (:ind-ref[ $val.obj-num, $val.gen-num]) )
                    !! nextsame
            }
            when Hash {
                self.ASSIGN-POS($pos, PDF::Object.compose( :stream($val), :$.reader ) )
                    if $val<stream>:exists;
                self.ASSIGN-POS($pos, PDF::Object.compose( :dict($val), :$.reader ) );
            }
            when Array {
                self.ASSIGN-POS($pos, PDF::Object.compose( :array($val), :$.reader ) );
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
