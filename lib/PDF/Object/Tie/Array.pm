use v6;

use PDF::Object::Tie;

role PDF::Object::Tie::Array does PDF::Object::Tie {

    has Array $.index is rw;  #| for typed indices

    sub tie-att-array($object, Int $idx, Attribute $att) is rw {

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
	      die "{$object.WHAT.^name}: missing required index: $idx"
		  if $att.is-required;
	      return Nil
	  }
	  die "{$object.WHAT.^name}.[$idx]: {$val.perl} - not of type: {$type.gist}"
	      unless $val ~~ $type
	      || $val ~~ Pair;	#| undereferenced - don't know it's type yet
	  $val;
	}

	Proxy.new(
	    FETCH => method {
		my $val = $object[$idx];
		$object.apply-att($val, $att);
		type-check($val, $att.type);
	    },
	    STORE => method ($val is copy) {
		my $lval = $object.lvalue($val);
		$object.apply-att($lval, $att);
		$object[$idx] := type-check($lval, $att.type);
	    });
    }

    multi method rw-accessor(Int $idx!, Attribute $att) {
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

	    my &meth = method { self.rw-accessor( $pos, $att ) };

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
	self.index //= PDF::Object::Tie::Array.compose(self.WHAT);
    }

    #| for array lookups, typically $foo[42]
    method AT-POS($pos) is rw {
        my $val := callsame;

        $val := $.deref(:$pos, $val)
	    if $val ~~ Pair | Array | Hash;

	self.apply-att($val, $.index[$pos])
	    if $.index[$pos]:exists;

	$val;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val) {
	my $lval = $.lvalue($val);

	self.apply-att($lval, $.index[$pos])
	    if $.index[$pos]:exists;

	nextwith($pos, $lval )
    }

    method push($val) {
        my $lval = self.lvalue($val);
        nextwith( $lval );
    }

    method unshift($val) {
        my $lval = self.lvalue($val);
        nextwith( $lval );
    }

    method splice($pos, $elems, **@replacement) {
        my @lvals = @replacement.map({ self.lvalue($_).item });
        nextwith( $pos, $elems, |@lvals);
    }

}
