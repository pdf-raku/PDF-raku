use v6;

use PDF::Object::Tie;

role PDF::Object::Tie::Hash does PDF::Object::Tie {

    has Hash $.entries is rw;

    sub tie-att-hash(Hash $object, Str $key, Attribute $att) is rw {

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
	      die "{$object.WHAT.^name}: missing required field: $key"
		  if $att.is-required;
	      return Nil
	  }
	  die "{$object.WHAT.^name}.$key: {$val.perl} - not of type: {$type.gist}"
	      unless $val ~~ $type
	      || $val ~~ Pair;	#| undereferenced - don't know it's type yet
	  $val;
	}

	#| find an heritable property
	proto sub inehrit(Hash $, Str $, Int :$hops) {*}
        multi sub inherit(Hash $object, Str $key where { $object{$key}:exists }, :$hops) {
	    $object{$key};
	}
	multi sub inherit(Hash $, Str $, Int :$hops! where {$hops > 100}) {
	    die "cyclical inheritance hierarchy"
	}
	multi sub inherit(Hash $object, Str $key where { $object<Parent>:exists }, Int :$hops = 1) {
	    inherit($object<Parent>, $key, :hops($hops + 1));
	}
	multi sub inherit(Hash $, Str $, :$hops) is default { Nil }

	Proxy.new( 
	    FETCH => method {
		my $val = $object{$key};
		$val //= inherit($object, $key)
		    if $att.is-inherited;
		type-check($val, $att.type);
	    },
	    STORE => method ($val is copy) {
		for $att.does.grep({ $val !~~ $_}) {
		    $val does $_;
		    $val.?tie-init;
		}
		$att.set_value($object, $object{$key} := type-check($val, $att.type));
	    });
    }

    multi method tie-att(Str $key!, $att is copy) {
	tie-att-hash(self, $key, $att);
    }

    method compose($class) {
	my $class-name = $class.^name;
	my %entries;

	for $class.^attributes.grep({.name !~~ /descriptor/ && .can('entry') }) -> $att {
	    my $key = $att.accessor-name;
	    %entries{$key} = $att;

	    my &meth = method { self.tie-att( $key, $att ) };

	    if $att.gen-accessor &&  ! $class.^declares_method($key) {
		$att.set_rw;
		$class.^add_method( $key, &meth );
	    }

	    $class.^add_method( $_ , &meth )
		unless $class.^declares_method($_)
		for $att.aliases;
	}
	%entries;
    }

    method tie-init {
	self.entries //= do {
	    PDF::Object::Tie::Hash.compose(self.WHAT);
	}
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
