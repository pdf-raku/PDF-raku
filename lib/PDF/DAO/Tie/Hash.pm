use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Hash does PDF::DAO::Tie {

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

    method rw-accessor(Str $key!, $att) {
	#| array of type, declared with '@' sigil, e.g.
        #| has PDF::DOM::Type::Catalog @.Kids is entry(:indirect);
	Proxy.new( 
	    FETCH => sub ($) {
		my $val := $att.tied.is-inherited
		    ?? inherit(self, $key)
		    !! self{$key};
		$att.tied.type-check($val, :$key);
	    },
	    STORE => sub ($, $val is copy) {
		my $lval = self.lvalue($val);
		$att.apply($lval);
		self{$key} := $att.tied.type-check($lval, :$key);
	    });
    }

    method tie-init {
	my $class = self.WHAT;
	my $class-name = $class.^name;

	for $class.^attributes.grep({.name !~~ /descriptor/ && .can('entry') }) -> $att {
	    my $key = $att.tied.accessor-name;
	    next if %.entries{$key}:exists;
	    %.entries{$key} = $att;
	}
    }

    #| for hash lookups, typically $foo<bar>
    method AT-KEY($key) is rw {
        my $val := callsame;

        $val := $.deref(:$key, $val)
	    if $val ~~ Pair | Array | Hash;

	my Attribute $att = %.entries{$key} // $.of-att;
	$att.apply($val)
	    if $att.defined;

	$val;
    }

    #| handle hash assignments: $foo<bar> = 42; $foo{$baz} := $x;
    method ASSIGN-KEY($key, $val) {
	my $lval = $.lvalue($val);

	my Attribute $att = %.entries{$key} // $.of-att;
	$att.apply($lval)
	    if $att.defined;

	nextwith($key, $lval )
    }

}
