use v6;

use PDF::COS::Tie :COSArrayAttrHOW;

role PDF::COS::Tie::Array does PDF::COS::Tie {

    has Attribute @.index is rw;    #| for typed indices

    method rw-accessor(Attribute $att) is rw {
        my UInt $pos := $att.index;
        my $val;
        my int $got = 0;

	Proxy.new(
	    FETCH => {
                $got ||= do {
                    $val := self.AT-POS($pos, :check) // $att.type;
                    1;
                }
                $val;
	    },
	    STORE => -> $, \v {
		$val := self.ASSIGN-POS($pos, v, :check);
                $got = 1;
	    }
        );
    }

    method tie-init {
       my \class = self.WHAT;

       for class.^attributes.grep(COSArrayAttrHOW) -> \att {
           my \pos = att.index;
           without @!index[pos] {
               $_ = att;
               my \key = att.cos.accessor-name;
               %.entries{key} = att;
           }
       }
    }

    method check {
        self.AT-POS($_, :check)
            for ^max(@!index, self);
        self
    }

    #| for array lookups, typically $foo[42]
    method AT-POS($pos, :$check) is rw {
        my $val := callsame;
        $val := $.deref(:$pos, $val)
	    if $val ~~ Pair | List | Hash;

	with $.index[$pos] // $.of-att {
            .tie($val, :$check);
        }
        else {
            $val;
        }
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

    multi method COERCE(PDF::COS::Tie::Array:D $array) {
        self.induce: $array;
    }
    multi method COERCE(List:D $array is raw, |c) {
        my Array:U $class := PDF::COS.load-array($array);
        self.induce: $class.new(:$array, |c);
    }
    multi method COERCE(Seq:D $seq is raw, |c) {
        self.COERCE($seq.Array, |c);
    }

}
