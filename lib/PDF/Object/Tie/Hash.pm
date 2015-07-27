use v6;

use PDF::Object::Tie;

role PDF::Object::Tie::Hash does PDF::Object::Tie {

    has Hash $.entries is rw;

    sub tie-att-hash(Hash $hash, Str $key, Attribute $att) is rw {

	#| untyped attribute
	multi sub type-check($val, Mu $type) is rw {
	    if !$val.defined {
		die "missing required field: $key"
		    if $att.is-required;
		return Nil
	    }
	    $val
	}
	#| type attribute
	multi sub type-check($val is rw, $type) is rw is default {
	  if !$val.defined {
	      die "{$hash.WHAT.^name}: missing required field: $key"
		  if $att.is-required;
	      return Nil
	  }
	  die "{$hash.WHAT.^name}.$key: {$val.perl} - not of type: {$type.gist}"
	      unless $val ~~ $type
	      || $val ~~ Pair;	#| undereferenced - don't know it's type yet
	  $val;
	}

	Proxy.new( 
	    FETCH => method {
		type-check($hash{$key}, $att.type);
	    },
	    STORE => method ($val is copy) {
		$att.set_value($hash, $hash{$key} := type-check($val, $att.type));
	    });
    }

    multi method tie-att(Str $key!, $att is copy) {
	tie-att-hash(self, $key, $att);
    }

    method compose($class) {
	my $class-name = $class.^name;
	my %entries;

	for $class.^attributes.grep({ .name ~~ /^'$!'<[A..Z]>/ && .can('entry') }) -> $att {
	    my $key = $att.name.subst(/^'$!'/, '');
	    %entries{$key} = $att;

	    unless $class.^declares_method($key) {
		$att.set_rw;
		$class.^add_method( $key, method {
		    self.tie-att( $key, $att ) } );
	    }
	}
	%entries;
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
	if $.entries{$key}:exists {
	    # tied to an attribute
	    $lval.obj-num //= -1
		if $.entries{$key}.is-indirect && $lval ~~ PDF::Object;
	    self."$key"() = $lval
	}
	else {
	    # undeclared, fallback to untied hash
	    nextwith( $key, $lval );
	}
    }
    
}
