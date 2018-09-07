use v6;

use PDF::COS::Tie :TiedEntry;

role PDF::COS::Tie::Hash
    does PDF::COS::Tie {

    #| resolve a heritable property by dereferencing /Parent entries
    sub find-prop($object, Str $key, :$seen is copy) {
	$object.AT-KEY($key, :check)
            // do with $object.AT-KEY('Parent', :check) {
                 $seen //= my %{Hash};
                 die "cyclical inheritance hierarchy"
                     if $seen{$object}++;
                 find-prop($_, $key, :$seen);
               }
    }

    method rw-accessor(Attribute $att, Str :$key!) is rw {
        # Optimise for frequent fetches. See also RT #126520
        my $val;
        my int $got = 0;

        Proxy.new(
            FETCH => {
                $got
                    ?? $val
                    !! do {
                        $got = 1;
                        $val := $att.tied.is-inherited
                            ?? find-prop(self, $key)
                            !! self.AT-KEY($key, :check);
                    }
            },
            STORE => -> $, \v {
                $val := self.ASSIGN-KEY($key, v, :check);
                $got = 1;
            }
        );
    }

    method tie-init {
       my \class = self.WHAT;
       for class.^attributes.grep(TiedEntry) -> \att {
           my \key = att.tied.accessor-name;
           %.entries{key} //= att;
       }
    }

    method check {
        self.AT-KEY($_, :check)
            for (flat self.keys, self.entries.grep(*.value.tied.is-required).keys).unique.sort;
        self.?cb-check();
        self
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key, :$check) is rw {
        my $val := callsame;

        $val := $.deref(:$key, $val)
	    if $val ~~ Pair | List | Hash;

	with %.entries{$key} // $.of-att {
            .tie($val, :$check);
        }
        else {
            $val;
        }
    }

    #| handle hash assignments: $foo<bar> = 42; $foo{$baz} := $x;
    method ASSIGN-KEY($key, $val, :$check) {
	my $lval = $.lvalue($val);
	my Attribute \att = %.entries{$key} // $.of-att;

        .tie($lval, :$check) with att;
	nextwith($key, $lval )
    }

}
