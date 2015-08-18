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
		for $att.does.grep({ $val !~~ $_}) {
		    $val does $_;
		    $val.?tie-init;
		}
		$att.set_value($array, $array[$idx] := type-check($val, $att.type));
	    });
    }

    multi method tie-att(Int $idx!, $att is copy) {
	tie-att-array(self, $idx, $att);
    }

    method compose($class) {
	my $class-name = $class.^name;
	my @index;

	for $class.^attributes.grep({.name !~~ /descriptor/ && .can('index') }) -> $att {
	    my $pos = $att.index;
	    die "redefinition of trait index($pos)"
		if @index[$pos];
	    @index[$pos] = $att;

	    my &meth = method { self.tie-att( $pos, $att ) };

	    my $key = $att.accessor-name;
	    if $att.gen-accessor && ! $class.^declares_method($key) {
		$att.set_rw;
		$class.^add_method( $key, &meth );
	    }

	    $class.^add_method( $_ , &meth )
		unless $class.^declares_method($_)
		for $att.aliases;
	}

	@index;
    }

    method tie-init {
	self.index //= do {
	    PDF::Object::Tie::Array.compose(self.WHAT);
	}
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
	if $.index[$pos]:exists {
	    # tied to an attribute
	    my $key = $.index[$pos].accessor-name;
	    $lval.obj-num //= -1
		if $.index[$pos].is-indirect && $lval ~~ PDF::Object;
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
