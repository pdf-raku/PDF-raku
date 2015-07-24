use v6;

use PDF::Object::Tie;

role PDF::Object::Tie::Hash does PDF::Object::Tie {

    # preferred
    sub tie-att-hash(Hash $hash, Str $key, Attribute $att) is rw {

	#| untyped attribute
	multi sub type-check(Hash $h, $val, Mu $type) is rw {
	    if !$val.defined {
		die "missing required field: $key"
		    if $att.is-required;
		return Nil
	    }
	    $val
	}
	#| type attribute
	multi sub type-check(Hash $h, $val is rw, $type) is rw is default {
	  if !$val.defined {
	      die "{$h.WHAT.^name}: missing required field: $key"
		  if $att.is-required;
	      return Nil
	  }
	  die "{$h.WHAT.^name}.$key: {$val.perl} - not of type: {$type.gist}"
	      unless $val ~~ $type
	      || $val ~~ Pair;	#| undereferenced - don't know it's type yet
	  $val;
	}

	Proxy.new( 
	    FETCH => method {
		type-check($hash, $hash{$key}, $att.type);
	    },
	    STORE => method ($val is copy) {
		$att.set_value($hash, $hash{$key} := type-check($hash, $val, $att.type));
	    });
    }

    multi method tie-att(Str $key!, $att is copy) {
	tie-att-hash(self, $key, $att);
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
	if $.tied-atts{$key}:exists {
	    # tied to an attribute
	    self."$key"() = $lval
	}
	else {
	    # undeclared, fallback to untied hash
	    nextwith( $key, $lval );
	}
    }
    
}
