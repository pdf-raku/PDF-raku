use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Array does PDF::DAO::Tie {

    has Attribute @.index is rw;    #| for typed indices

    method rw-accessor(Str $, Attribute $att) is rw {

        my UInt $key = $att.index;

	Proxy.new(
	    FETCH => sub ($) {
		my $val := self[$key];
		$att.tied.type-check($val, :$key);
	    },
	    STORE => sub ($, $val is copy) {
		my $lval = self.lvalue($val);
		$att.apply($lval);
		self[$key] := $att.tied.type-check($lval, :$key);
	    });

    }

    method tie-init {
	my $class = self.WHAT;
	my $class-name = $class.^name;

	for $class.^attributes.grep({.name !~~ /descriptor/ && .can('index') }) -> $att {
	    my $pos = $att.index;
	    my $key = $att.tied.accessor-name;
	    next if @!index[$pos];
	    @!index[$pos] = $att;
            %.entries{$key} = $att;
	}
    }

    #| for array lookups, typically $foo[42]
    method AT-POS($pos) is rw {
        my $val := callsame;

        $val := $.deref(:$pos, $val)
	    if $val ~~ Pair | Array | Hash;

	my Attribute $att = $.index[$pos] // $.of-att;
	.apply($val) with $att;

	$val;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val) {
	my $lval = $.lvalue($val);

	my Attribute $att = $.index[$pos] // $.of-att;
	.apply($lval) with $att;

	nextwith($pos, $lval )
    }

    method push($val) {
	self[ +self ] = $val;
    }

}
