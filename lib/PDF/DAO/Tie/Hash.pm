use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Hash does PDF::DAO::Tie {

    has Attribute %.entries is rw;
    has Bool $!composed;

    sub tie-att-hash(Hash $object, Str $key, Attribute $att) is rw {

	#| array of type, declared with '@' sigil, e.g.
        #| has PDF::DOM::Type::Catalog @.Kids is entry(:indirect);
	multi sub type-check($val, Positional[Mu] $type) {
	    type-check($val, Array);
	    if $val.defined {
		die "array not of length: {$att.tied.length}"
		    if $att.tied.length && +$val != $att.tied.length;
		my $of-type = $type.of;
		type-check($_, $of-type)
		for $val.values;
	    }
	    else {
		die "missing required field: $key"
		    if $att.tied.is-required;
		return Nil
	    }
	    $val;
	}

	multi sub type-check($val, Associative[Mu] $type) {
	    type-check($val, Hash);
	    if $val.defined {
		my $of-type = $type.of;
		type-check($_, $of-type)
		for $val.values;
	    }
	    else {
		die "missing required field: $key"
		    if $att.tied.is-required;
		return Nil
	    }
	    $val;
	}

	#| untyped attribute
	multi sub type-check($val is copy, Mu $type) is rw {
	    if !$val.defined {
		die "missing required field: $key"
		    if $att.tied.is-required;
		return Nil
	    }
	    $val
	}
	#| type attribute
	multi sub type-check($val is copy, $type) is rw is default {
	    if !$val.defined {
	      die "{$object.WHAT.^name}: missing required field: $key"
		  if $att.tied.is-required;
	      return Nil
	  }
	  die "{$object.WHAT.^name}.$key: {$val.WHAT.gist} - not of type: {$type.gist}"
	      unless $val ~~ $type
	      || $val ~~ Pair;	#| undereferenced - don't know it's type yet
	  $val;
	}

	#| resolve a heritable property by dereferencing /Parent entries
	proto sub inehrit(Hash $, Str $, Int :$hops) {*}
        multi sub inherit(Hash $object, Str $key where { $object{$key}:exists }, :$hops) {
	    $object{$key};
	}
	multi sub inherit(Hash $object, Str $key where { $object<Parent>:exists }, Int :$hops is copy = 1) {
	    die "cyclical inheritance hierarchy"
		if ++$hops > 100;
	    inherit($object<Parent>, $key, :$hops);
	}
	multi sub inherit(Mu $, Str $, :$hops) is default { Nil }

	Proxy.new( 
	    FETCH => sub ($) {
		my $val := $att.tied.is-inherited
		    ?? inherit($object, $key)
		    !! $object{$key};
		type-check($val, $att.tied.type);
	    },
	    STORE => sub ($, $val is copy) {
		my $lval = $object.lvalue($val);
		$att.apply($lval);
		$object{$key} := type-check($lval, $att.tied.type);
	    });
    }

    method rw-accessor(Str $key!, $att) {
	tie-att-hash(self, $key, $att);
    }

    method compose returns Bool {
	my $class = self.WHAT;
	my $class-name = $class.^name;

	for $class.^attributes.grep({.name !~~ /descriptor/ && .can('entry') }) -> $att {
	    my $key = $att.tied.accessor-name;
	    %!entries{$key} = $att;

	    my &meth = method { self.rw-accessor( $key, $att ) };

	    if $att.tied.gen-accessor &&  ! $class.^declares_method($key) {
		$att.set_rw;
		$class.^add_method( $key, &meth );
	    }

	    for $att.tied.aliases -> $alias {
		$class.^add_method( $alias, &meth )
		    unless $class.^declares_method($alias)
	    }
	}

	True
    }

    method tie-init {
	$!composed ||= self.compose;
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key) is rw {
        my $val := callsame;

        $val := $.deref(:$key, $val)
	    if $val ~~ Pair | Array | Hash;

	my $att = $.entries{$key} // $.of-att;
	$att.apply($val)
	    if $att.defined;

	$val;
    }

    #| handle hash assignments: $foo<bar> = 42; $foo{$baz} := $x;
    method ASSIGN-KEY($key, $val) {
	my $lval = $.lvalue($val);

	my $att = $.entries{$key} // $.of-att;
	$att.apply($lval)
	    if $att.defined;

	nextwith($key, $lval )
    }
    
}
