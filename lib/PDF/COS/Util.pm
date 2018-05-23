use v6;

module PDF::COS::Util {

    use PDF::COS;

    proto sub to-ast(|) is export(:to-ast) {*};
    multi sub to-ast(Pair $p!) {$p}
    multi sub to-ast(PDF::COS $object!) {$object.content}
    multi sub to-ast($other!) is default {
        ast-coerce $other
    }
    proto sub ast-coerce(|) is export(:ast-coerce) {*};
    multi sub ast-coerce(Int $int!) {:$int}
    multi sub ast-coerce(Numeric $real!) {:$real}
    multi sub ast-coerce(Str $literal!) {:$literal}

    my %seen{Any};

    multi sub ast-coerce(Hash $_dict!) {
	my $dict = %seen{$_dict};

	without $dict {
	    $dict = temp %seen{$_dict} = {};
	    $dict{.key} = to-ast(.value)
                for $_dict.pairs;
	}

	:$dict;
    }

    multi sub ast-coerce(array $a) {
        my $tag = do given $a.of {
                 when num|num64 { 'real' }
                 when str       { 'literal' }
                 default        { 'int'  }
        };
        :array[ $a.map({ $tag => $_ }) ]
    }

    multi sub ast-coerce(List $a where .of ~~ Numeric) {
        my $tag = $a.of ~~ Int ?? 'int' !! 'real';
        :array[ $a.map({ $tag => $_ }) ]
    }

    multi sub ast-coerce(List $_list!) {
	my $array = %seen{$_list};

	without $array {
	    $array = temp %seen{$_list} = [ ];
	    $array.push( to-ast( $_ ) )
                for $_list.values;
	}

        :$array;
    }

    sub date-time-formatter(DateTime $dt) returns Str is export(:date-time-formatter) {
	my Int $offset-min = $dt.offset div 60;
	my Str $tz-sign = 'Z';

	if $offset-min < 0 {
	    $tz-sign = '-';
	    $offset-min = - $offset-min;
	}
	elsif $offset-min > 0 {
	    $tz-sign = '+';
	}

	my UInt $tz-min = $offset-min mod 60;
	my UInt $tz-hour = $offset-min div 60;

	my $date-spec = '%04d%02d%02d'.sprintf($dt.year, $dt.month, $dt.day);
	my $time-spec = '%02d%02d%02d'.sprintf($dt.hour, $dt.minute, $dt.second);
	my Str $tz-spec = "%s%02d'%02d'".sprintf($tz-sign, $tz-hour, $tz-min);

       [~] "D:", $date-spec, $time-spec, $tz-spec;
    }

    multi sub ast-coerce(DateTime $date-time!) {
	my Str $literal = date-time-formatter($date-time);
	:$literal
    }
    multi sub ast-coerce(Bool $bool!) {:$bool}
    multi sub ast-coerce($_) is default {
        when !.defined   { :null(Any) }
        when Enumeration { ast-coerce(.value) }
        default {
            die "don't know how to ast-coerce: {.perl}";
        }
    }

    proto sub from-ast(|) is export(:from-ast) {*};

    multi sub from-ast( Pair $p) {
        from-ast( |$p );
    }

    #| for JSON deserialization, e.g. { :int(42) } => :int(42)
    use PDF::Grammar:ver(v0.1.0+) :AST-Types;
    BEGIN my %ast-types = AST-Types.enums;
    multi sub from-ast( Hash $h! where { .keys == 1 && (%ast-types{.keys[0]}:exists)} ) {
        from-ast( |$h )
    }

    multi sub from-ast( $other!)            { $other }

    multi sub from-ast( Array :$array! )    { $array }

    multi sub from-ast( Bool :$bool! )      { $bool }

    multi sub from-ast( Hash :$dict! )      { $dict }

    multi sub from-ast( Str :$encoded! )    { $encoded }

    multi sub from-ast( Str :$hex-string! ) { PDF::COS.coerce :$hex-string }

    multi sub from-ast( Array :$ind-ref! )  { :$ind-ref }

    multi sub from-ast( Array :$ind-obj! )  { from-ast |$ind-obj[2].kv }

    multi sub from-ast( Numeric :$int! )    { PDF::COS.coerce :$int; }

    multi sub from-ast( Str :$literal! )    { PDF::COS.coerce :$literal }

    multi sub from-ast( Str :$name! )       { PDF::COS.coerce :$name }

    multi sub from-ast( Numeric :$real! )   { PDF::COS.coerce :$real }

    multi sub from-ast( Hash :$stream! )    { $stream }

    multi sub from-ast( :$null! )           { Any }

    multi sub from-ast( *@args, *%opt ) is default {
        die "unexpected from-ast arguments: {[@args].perl}"
            if @args;
        die "unable to from-ast {%opt.keys} struct: {%opt.perl}"
    }

}
