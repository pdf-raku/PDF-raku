use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Array does PDF::DAO::Tie {

    has Attribute @.index is rw;    #| for typed indices
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
	    FETCH => sub ($) {
		my $val := $object[$idx];
		type-check($val, $att.tied.type);
	    },
	    STORE => sub ($, $val is copy) {
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

	    for $att.tied.aliases -> $alias {
		$class.^add_method( $alias, &meth )
		    unless $class.^declares_method($alias)
	    }
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

	my $att = $.index[$pos] // $.item-att;
	$att.apply($val)
	    if $att.defined;

	$val;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val) {
	my $lval = $.lvalue($val);

	my $att = $.index[$pos] // $.item-att;
	$att.apply($lval)
	    if $att.defined;

	nextwith($pos, $lval )
    }

    method push($val) {
	self[ +self ] = $val;
    }

}
