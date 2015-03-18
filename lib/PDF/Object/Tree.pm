use v6;

role PDF::Object::Tree {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

    #| for array lookups, typically $foo[42]
    method AT-POS(|c) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref(:pos(c[0]),$result )
            !! $result;
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY(|c) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref(:key(c[0]),$result)
            !! $result;
    }

    multi method deref(Pair $ind-ref! is rw) {
        return $ind-ref unless $ind-ref.key eq 'ind-ref'
            && $.reader;

        my $obj-num = $ind-ref.value[0];
        my $gen-num = $ind-ref.value[1];

        $.reader.ind-obj( $obj-num, $gen-num ).object;
    }

    multi method deref($value,:$key!) {
        return $value if $value.can('deref');        
        self.ASSIGN-KEY($key, $value but PDF::Object::Tree);
    }

    multi method deref($value,:$pos!) {
        return $value if $value.can('deref');        
        self.ASSIGN-POS($pos, $value but PDF::Object::Tree);
    }

}
