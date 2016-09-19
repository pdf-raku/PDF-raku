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

    my Array %index;
    my Hash %entries; # {Any}
    method !mixin {
	my \class = self.^name;
        unless %entries{class}:exists {
            my Attribute %atts;
            my Attribute @idx;
            for self.^attributes.grep({.name !~~ /descriptor/ && .can('index') }) -> \att {
                my \pos = att.index;
                my \key = att.tied.accessor-name;
                @idx[pos] = att;
                %atts{key} = att;
            }
            %entries{class} = %atts;
            %index{class} = @idx;
        }
    }

    method entries {
        self!mixin;
        %entries{self.^name};
    }

    method index {
        self!mixin;
        %index{self.^name};
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
