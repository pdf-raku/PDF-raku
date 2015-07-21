use v6;

use PDF::Object::Tie;

role PDF::Object::Tie::Array does PDF::Object::Tie {

    method tie(Int $idx, $att is rw) {
	my $v := self[$idx];
	if self[$idx]:exists {
	    if $att !=== $v {
		# bind
		$att = $v;
		self[$idx] := $att;
	    }
	}
	else {
	    $att = Nil;
	}
        $att;
    }

    #| for array lookups, typically $foo[42]
    method AT-POS($pos) is rw {
        my $result := callsame;
        $result ~~ Pair | Array | Hash
            ?? $.deref(:$pos, $result )
            !! $result;
    }

    #| handle array assignments: $foo[42] = 'bar'; $foo[99] := $baz;
    method ASSIGN-POS($pos, $val) {
        my $lval = self.lvalue($val);
        nextwith( $pos, $lval );
    }

    method push($val) {
        my $lval = self.lvalue($val);
        nextwith( $lval );
    }

    method unshift($val) {
        my $lval = self.lvalue($val);
        nextwith( $lval );
    }

    method splice($pos, $elems, *@replacement) {
        my @lvals = @replacement.map({ self.lvalue($_).item });
        nextwith( $pos, $elems, |@lvals);
    }

}
