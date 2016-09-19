use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Hash does PDF::DAO::Tie {

    #| resolve a heritable property by dereferencing /Parent entries
    proto sub inehrit(Hash $, Str $, Int :$hops) {*}
    multi sub inherit(Hash $object, Str $key where { $object{$key}:exists }, :$hops) {
        temp $object.strict = True;
	$object{$key};
    }
    multi sub inherit(Hash $object, Str $key where { $object<Parent>:exists }, Int :$hops is copy = 1) {
	die "cyclical inheritance hierarchy"
	    if ++$hops > 100;
	inherit($object<Parent>, $key, :$hops);
    }
    multi sub inherit(Mu $, Str $, :$hops) is default { Nil }

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

    my Hash %entries; #{Any}
    method entries {
	my \class = self.^name;
        unless %entries{class}:exists {
            my Attribute %atts;
            for self.^attributes.grep({.name !~~ /descriptor/ && .can('entry') }).list -> \att {
	        %atts{att.tied.accessor-name} = att;
	    }
            %entries{class} = %atts;
        }
        %entries{class}
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key) is rw {
        my $val := callsame;
        $val := $.deref(:$key, $val)
	    if $val ~~ Pair | Array | Hash;

	my Attribute \att = %.entries{$key} // $.of-att;
         with att {
	     .apply($val);
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
	    .apply($lval);
            .tied.type-check($lval, :$key)
                 if $.strict;
        }
	nextwith($key, $lval )
    }

}
