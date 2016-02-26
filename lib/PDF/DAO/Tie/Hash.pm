use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Hash does PDF::DAO::Tie {

    has Attribute %.entries is rw;

    sub tie-att-hash(Hash $object, Str $key, Attribute $att) is rw {

	#| array of type, declared with '@' sigil, e.g.
        #| has PDF::DOM::Type::Catalog @.Kids is entry(:indirect);

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
		$att.tied.type-check($val, :$key);
	    },
	    STORE => sub ($, $val is copy) {
		my $lval = $object.lvalue($val);
		$att.apply($lval);
		$object{$key} := $att.tied.type-check($lval, :$key);
	    });
    }

    method rw-accessor(Str $key!, $att) {
	tie-att-hash(self, $key, $att);
    }

    method tie-init {
	my $class = self.WHAT;
	my $class-name = $class.^name;

	for $class.^attributes.grep({.name !~~ /descriptor/ && .can('entry') }) -> $att {
	    my $key = $att.tied.accessor-name;
	    next if %!entries{$key}:exists;
	    %!entries{$key} = $att;

	    if $att.tied.gen-accessor &&  ! $class.^declares_method($key) {
		$att.set_rw;
		my &meth = method { self.rw-accessor( $key, $att ) };
		$class.^add_method( $key, &meth );
	    }
	}
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
