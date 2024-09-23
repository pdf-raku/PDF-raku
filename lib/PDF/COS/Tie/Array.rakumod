use v6;

unit role PDF::COS::Tie::Array;

use PDF::COS::Tie :COSArrayAttrHOW;
also does PDF::COS::Tie;

has Attribute @.index is rw;    #| for typed indices
has Attribute %.entries;

method rw-accessor(Attribute $att) is rw {
    my UInt $pos := $att.index;
    my $val;
    my int $got = 0;

    sub FETCH($) {
        $got ||= do {
            $val := self.AT-POS($pos, :check) // $att.type;
            1;
        }
        $val;
    }

    sub STORE($, \v) {
        $val := self.ASSIGN-POS($pos, v, :check);
        $got = 1;
    }

    Proxy.new: :&FETCH, :&STORE;
}

method tie-init {
   my \class = self.WHAT;

   for class.^attributes.grep(COSArrayAttrHOW) -> \att {
       @!index[att.index] //= (%!entries{att.cos.accessor-name} = att);
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
    self.BIND-POS($pos, $lval )
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

