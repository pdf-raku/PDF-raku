use v6;

use PDF::COS::Tie;

role PDF::COS::Tie::Hash does PDF::COS::Tie {

    #| resolve a heritable property by dereferencing /Parent entries
    sub inherit($object, Str $key, :$seen is copy) {
	$object.AT-KEY($key, :check)
            // do with $object.AT-KEY('Parent', :check) {
                 $seen //= my %{Hash};
                 die "cyclical inheritance hierarchy"
                     if $seen{$object}++;
                 inherit($_, $key, :$seen);
               }
    }

    method rw-accessor(Attribute $att, Str :$key!) is rw {
        Proxy.new(
            FETCH => sub ($) {
                $att.tied.is-inherited
	            ?? inherit(self, $key)
	            !! self.AT-KEY($key, :check);
            },
            STORE => sub ($, \v) {
                self.ASSIGN-KEY($key, v, :check);
            }
        );
    }

    method tie-init {
       my \class = self.WHAT;
       for class.^attributes.grep(*.can('entry')) -> \att {
           my \key = att.tied.accessor-name;
           next if %.entries{key}:exists;
           %.entries{key} = att;
       }
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key, :$check) is rw {
        my $val := callsame;
	my Attribute \att = %.entries{$key} // $.of-att;

        $val := $.deref(:$key, $val)
	    if $val ~~ Pair | List | Hash;

        .tie($val, :$check) with att;
        $val;
    }

    #| handle hash assignments: $foo<bar> = 42; $foo{$baz} := $x;
    method ASSIGN-KEY($key, $val, :$check) {
	my $lval = $.lvalue($val);
	my Attribute \att = %.entries{$key} // $.of-att;

        .tie($lval, :$check) with att;
	nextwith($key, $lval )
    }

}
