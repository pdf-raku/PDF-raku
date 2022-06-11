use v6;

use PDF::COS::Tie :COSDictAttrHOW;

role PDF::COS::Tie::Hash
    does PDF::COS::Tie {

    has Str %.aliases;
    has Bool %.required-entries;

    use PDF::COS;
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
        my $val;
        my int $got = 0;

        Proxy.new(
            FETCH => {
                $got ||= do {
                    $val := (
                        $att.cos.is-inherited
                            ?? inherit(self, $key)
                            !! self.AT-KEY($key, :check)
                    ) // $att.type;
                    1;
                }
                $val;
            },
            STORE => -> $, \v {
                $val := self.ASSIGN-KEY($key, v, :check);
                $got = 1;
            }
        );
    }

    method tie-init {
       my \class = self.WHAT;
       for class.^attributes.grep(COSDictAttrHOW) -> \att {
           given att.cos {
               my \key  = .accessor-name;
               %.entries{key} //= att;
               %!required-entries{key} = True if .is-required;
               with .alias -> \alias {
                   %!aliases{alias} = key;
                   self{key} //= $_
                       with self{alias}:delete;
               }
           }
       }
    }

    method check {
        self.AT-KEY($_, :check)
            for unique(self.keys.Slip, %!required-entries.keys.sort.Slip);
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

    multi method COERCE(PDF::COS::Tie::Hash $hash) {
        self.induce: $hash;
    }
    multi method COERCE(Hash $dict is raw, |c) {
        my Hash:U $class := PDF::COS.load-dict($dict);
        self.induce: $class.new(:$dict, |c);
    }
}
