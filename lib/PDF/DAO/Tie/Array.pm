use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Array does PDF::DAO::Tie {

    has Attribute @.index is rw;    #| for typed indices

    method rw-accessor(Attribute $att) is rw {

        my UInt \pos = $att.index;

	Proxy.new(
	    FETCH => sub (\p) {
                temp self.strict = True;
		self[pos];
	    },
	    STORE => sub (\p, \v) {
                temp self.strict = True;
		self[pos] := v;
	    });
    }

    method tie-init {
	my \class = self.WHAT;

	for class.^attributes.grep({.name !~~ /descriptor/ && .can('index') }) -> \att {
	    my \pos = att.index;
	    my \key = att.tied.accessor-name;
	    next if @!index[pos];
	    @!index[pos] = att;
            %.entries{key} = att;
	}
    }

    #| for array lookups, typically $foo[42]
    method AT-POS($pos) is rw {
        my $val := callsame;

        $val := $.deref(:$pos, $val)
	    if $val ~~ Pair | Array | Hash;

	my Attribute \att = $.index[$pos] // $.of-att;
        with att {
	    .apply($val);
            .tied.type-check($val, :key(att.index))
                if $.strict;
        }

	$val;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val) {
	my $lval = $.lvalue($val);

	my Attribute \att = $.index[$pos] // $.of-att;
        with att {
	    .apply($lval);
            .tied.type-check($lval, :key(att.index))
                if $.strict;
        }

	nextwith($pos, $lval )
    }

    method push($val) {
	self[ +self ] = $val;
    }

}
