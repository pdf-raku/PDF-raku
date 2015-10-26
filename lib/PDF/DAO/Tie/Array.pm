use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Array does PDF::DAO::Tie {

    has Attribute @.index is rw;    #| for typed indices
    has Attribute $.positional is rw;      #| default attribute
    has Bool $!composed;

    sub tie-att-array($object, UInt $idx, Attribute $att) is rw {

	sub type-check($val is copy, Mu $type) is rw is default {
	  if !$val.defined {
	      die "{$object.WHAT.^name}: missing required index: $idx"
		  if $att.tied.is-required;
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
		$att.apply($val);
		type-check($val, $att.tied.type);
	    },
	    STORE => method ($val is copy) {
		my $lval = $object.lvalue($val);
		$att.apply($lval);
		$object[$idx] := type-check($lval, $att.tied.type);
	    });
    }

    multi method rw-accessor(UInt $idx!, Attribute $att) {
	tie-att-array(self, $idx, $att);
    }

    method compose( --> Bool) {
	my $class = self.WHAT;
	my $class-name = $class.^name;

	for $class.^attributes.grep({.name !~~ /descriptor/ && .can('index') }) -> $att {
	    my $pos = $att.index;
	    die "redefinition of trait index($pos)"
		if @!index[$pos];
	    @!index[$pos] = $att;

	    my &meth = method { self.rw-accessor( $pos, $att ) };

	    my $key = $att.tied.accessor-name;
	    if $att.tied.gen-accessor && ! $class.^declares_method($key) {
		$att.set_rw;
		$class.^add_method( $key, &meth );
	    }

	    $class.^add_method( $_ , &meth )
		unless $class.^declares_method($_)
		for $att.tied.aliases;
	}

	True;
    }

    method tie-init {
	$!composed ||= self.compose;
    }

    #| for array lookups, typically $foo[42]
    method AT-POS($pos) is rw {
        my $val := callsame;

        $val := $.deref(:$pos, $val)
	    if $val ~~ Pair | Array | Hash;

	my $att = $.index[$pos] // $.positional;
	$att.apply($val)
	    if $att.defined;

	$val;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val) {
	my $lval = $.lvalue($val);

	my $att = $.index[$pos] // $.positional;
	$att.apply($lval)
	    if $att.defined;

	nextwith($pos, $lval )
    }

    method push($val) {
	self[ +self ] = $val;
    }

}
