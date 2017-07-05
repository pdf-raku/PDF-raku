use v6;

use PDF::DAO::Tie;

role PDF::DAO::Tie::Array does PDF::DAO::Tie {

    has Attribute @.index is rw;    #| for typed indices

    method rw-accessor(Attribute $att) is rw {

        my UInt \pos = $att.index;

	Proxy.new(
	    FETCH => sub ($) {
		self.AT-POS(pos, :check);
	    },
	    STORE => sub ($, \v) {
		self.ASSIGN-POS(pos, v, :check);
	    });
    }

    method tie-init {
       my \class = self.WHAT;

       for class.^attributes.grep({.name !~~ /descriptor/ && .can('index') }) -> \att {
           my \pos = att.index;
           without @!index[pos] {
               $_ = att;
               my \key = att.tied.accessor-name;
               %.entries{key} = att;
           }
       }
    }

    #| for array lookups, typically $foo[42]
    method AT-POS($pos, :$check) is rw {
        my $val := callsame;

        $val := $.deref(:$pos, $val)
	    if $val ~~ Pair | Array | Hash;

	my Attribute \att = $.index[$pos] // $.of-att;
        with att {
	    .tie($val);
            .tied.type-check($val, :key(.index))
                if $check;
        }

	$val;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val, :$check) {
	my $lval = $.lvalue($val);

	my Attribute \att = $.index[$pos] // $.of-att;
        with att {
	    .tie($lval);
            .tied.type-check($lval, :key(.index))
                if $check;
        }

	nextwith($pos, $lval )
    }

    method push($val) {
	self[ +self ] = $val;
    }

}
