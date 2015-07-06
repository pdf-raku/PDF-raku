use v6;

use PDF::Object::Tie;

role PDF::Object::Tie::Hash does PDF::Object::Tie {

    method tie(*%kv where {+%kv == 1}) {
        my $key := %kv.keys[0]; my $att = %kv.values[0];
        my $v := self{$key};
        $att //= $v if $v.defined;
        $att.defined
            ?? do { self{$key} := $att }
            !! $att;
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key) is rw {
        my $result := callsame;

        $result ~~ Pair | Array | Hash
            ?? $.deref(:$key, $result)
            !! $result;
    }

    #| handle hash assignments: $foo<bar> = 42; $foo{$baz} := $x;
    method ASSIGN-KEY($key, $val) {
        my $lval = self.lvalue($val);
        nextwith( $key, $lval );
    }
    
    method DELETE-KEY($key) {
        # Nil any bound variables
        self{$key} = Nil;
        nextsame;
    }

}
