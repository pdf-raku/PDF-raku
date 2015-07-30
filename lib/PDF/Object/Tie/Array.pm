use v6;

use PDF::Object::Tie;

role PDF::Object::Tie::Array does PDF::Object::Tie {

    has Array $.index is rw;

    sub tie-att-array(Array $array, Int $idx, Attribute $att) is rw {

	#| untyped attribute
	multi sub type-check($val, Mu $type) is rw {
	    if !$val.defined {
		die "missing required array entry: $idx"
		    if $att.is-required;
		return Nil
	    }
	    $val
	}
	#| type attribute
	multi sub type-check($val is rw, $type) is rw is default {
	  if !$val.defined {
	      die "{$array.WHAT.^name}: missing required index: $idx"
		  if $att.is-required;
	      return Nil
	  }
	  die "{$array.WHAT.^name}.[$idx]: {$val.perl} - not of type: {$type.gist}"
	      unless $val ~~ $type
	      || $val ~~ Pair;	#| undereferenced - don't know it's type yet
	  $val;
	}

	Proxy.new( 
	    FETCH => method {
		type-check($array[$idx], $att.type);
	    },
	    STORE => method ($val is copy) {
		$att.set_value($array, $array[$idx] := type-check($val, $att.type));
	    });
    }

    multi method tie-att(Int $idx!, $att is copy) {
	tie-att-array(self, $idx, $att);
    }

    method compose($class) {
	my $class-name = $class.^name;
	my @index;

	for $class.^attributes.grep({ .name ~~ /^'$!'<[A..Z]>/ && .can('index') }) -> $att {
	    my $key = $att.name.subst(/^'$!'/, '');
	    my $pos = $att.index;
	    die "redefinition of trait index($pos)"
		if @index[$pos];
	    @index[$pos] = $key;

	    if $att.gen-accessor && ! $class.^declares_method($key) {
		$att.set_rw;
		$class.^add_method( $key, method {
		    self.tie-att( $pos, $att ) } );
	    }
	}
	@index;
    }

    #| for array lookups, typically $foo[42]
    method AT-POS($pos) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref(:$pos, $result )
            !! $result;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val) {
        my $lval = self.lvalue($val);
	if my $key = $.index[$pos] {
	    # tied to an attribute
	    self."$key"() = $lval
	}
	else {
	    # undeclared, fallback to untied array
	    nextwith( $pos, $lval );
	}
    }

    method push($val) {
        my $lval = self.lvalue($val);
        nextwith( $lval );
    }

    method unshift($val) {
        my $lval = self.lvalue($val);
        nextwith( $lval );
    }

    method splice($pos, $elems, *@replacement) {
        my @lvals = @replacement.map({ self.lvalue($_).item });
        nextwith( $pos, $elems, |@lvals);
    }

}
