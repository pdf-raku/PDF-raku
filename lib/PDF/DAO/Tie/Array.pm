use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Array does PDF::DAO::Tie {

    has Attribute @.index is rw;    #| for typed indices

    sub tie-att-array($object, UInt $key, Attribute $att) is rw {

	Proxy.new(
	    FETCH => sub ($) {
		my $val := $object[$key];
		$att.tied.type-check($val, :$key);
	    },
	    STORE => sub ($, $val is copy) {
		my $lval = $object.lvalue($val);
		$att.apply($lval);
		$object[$key] := $att.tied.type-check($lval, :$key);
	    });
    }

    multi method rw-accessor(UInt $idx!, Attribute $att) {
	tie-att-array(self, $idx, $att);
    }

    method tie-init( --> Bool) {
	my $class = self.WHAT;
	my $class-name = $class.^name;

	for $class.^attributes.grep({.name !~~ /descriptor/ && .can('index') }) -> $att {
	    my $pos = $att.index;
	    next if @!index[$pos];
	    @!index[$pos] = $att;

	    my &meth = method { self.rw-accessor( $pos, $att ) };

	    my $key = $att.tied.accessor-name;
	    if $att.tied.gen-accessor && ! $class.^declares_method($key) {
		$att.set_rw;
		$class.^add_method( $key, &meth );
	    }

	    for $att.tied.aliases -> $alias {
		$class.^add_method( $alias, &meth )
		    unless $class.^declares_method($alias)
	    }
	}

	True;
    }

    #| for array lookups, typically $foo[42]
    method AT-POS($pos) is rw {
        my $val := callsame;

        $val := $.deref(:$pos, $val)
	    if $val ~~ Pair | Array | Hash;

	my $att = $.index[$pos] // $.of-att;
	$att.apply($val)
	    if $att.defined;

	$val;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val) {
	my $lval = $.lvalue($val);

	my $att = $.index[$pos] // $.of-att;
	$att.apply($lval)
	    if $att.defined;

	nextwith($pos, $lval )
    }

    method push($val) {
	self[ +self ] = $val;
    }

}
