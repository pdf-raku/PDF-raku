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

       for class.^attributes.grep(*.can('index')) -> \att {
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
	my Attribute \att = $.index[$pos] // $.of-att;

        $val := $.deref(:$pos, $val)
	    if $val ~~ Pair | List | Hash;

        .tie($val, :$check) with att;
	$val;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val, :$check) {
	my $lval = $.lvalue($val);
	my Attribute \att = $.index[$pos] // $.of-att;

        .tie($lval, :$check) with att;
	nextwith($pos, $lval )
    }

    method push($val) {
	self[ +self ] = $val;
    }

}
