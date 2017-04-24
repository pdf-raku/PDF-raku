use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Hash does PDF::DAO::Tie {

    #| resolve a heritable property by dereferencing /Parent entries
    sub inherit($object, Str $key, :$seen is copy) {
	$object{$key} // do with $object<Parent> {
            $seen //= my %{Hash};
	    die "cyclical inheritance hierarchy"
	        if $seen{$object}++;
	    inherit($_, $key, :$seen);
        }
    }

    method rw-accessor(Attribute $att, Str :$key!) is rw {
        Proxy.new(
            FETCH => sub (\p) {
                temp self.strict = True;
                $att.tied.is-inherited
	            ?? inherit(self, $key)
	            !! self{$key};
            },
            STORE => sub (\p, \v) {
                temp self.strict = True;
                self{$key} = v;
            }
        );
    }

    method tie-init {
       my \class = self.WHAT;
       for class.^attributes.grep({.name !~~ /descriptor/ && .can('entry') }) -> \att {
           my \key = att.tied.accessor-name;
           next if %.entries{key}:exists;
           %.entries{key} = att;
       }
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key) is rw {
        my $val := callsame;
        $val := $.deref(:$key, $val)
	    if $val ~~ Pair | Array | Hash;

	my Attribute \att = %.entries{$key} // $.of-att;
         with att {
	     .tie($val);
             .tied.type-check($val, :$key)
                 if $.strict;
         }
         $val;
    }

    #| handle hash assignments: $foo<bar> = 42; $foo{$baz} := $x;
    method ASSIGN-KEY($key, $val) {
	my $lval = $.lvalue($val);

	my Attribute \att = %.entries{$key} // $.of-att;
        with att {
	    .tie($lval);
            .tied.type-check($lval, :$key)
                 if $.strict;
        }
	nextwith($key, $lval )
    }

}
