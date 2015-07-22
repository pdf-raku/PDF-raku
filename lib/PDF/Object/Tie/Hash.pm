use v6;

use PDF::Object::Tie;

role PDF::Object::Tie::Hash does PDF::Object::Tie {

    # preferred
    multi method tie(Str $key!, $att is rw) {
	my $v;
        if self{$key}:exists {
            $v := self{$key};
            if $att !=== $v {
                # bind
                $att.set_value(self, $v);
            }
        }
        else {
	    $v = Nil;
            $att.set_value(self, $v);
        }
        $v;
    }    

    # depreciated
    multi method tie($att is rw) is default {
        my Str $key = $att.VAR.name.subst(/^'$!'/, '');
	warn :deprecated{ :$key }.perl;
        if self{$key}:exists {
            my $v := self{$key};
            if $att !=== $v {
                # bind
                $att = $v;
                self{$key} := $att;
            }
        }
        else {
            $att = Nil;
        }
        $att;
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
    
}
