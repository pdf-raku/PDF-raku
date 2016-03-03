use v6;

module PDF::DAO::Util {

    use PDF::DAO;

    proto sub to-ast(|) is export(:to-ast) {*};
    multi sub to-ast(Pair $p!) {$p}
    multi sub to-ast(PDF::DAO $object!) {$object.content}
    multi sub to-ast($other!) is default {
        to-ast-native $other
    }
    proto sub to-ast-native(|) is export(:to-ast-native) {*};
    multi sub to-ast-native(Int $int!) {:$int}
    multi sub to-ast-native(Numeric $real!) {:$real}
    multi sub to-ast-native(Str $literal!) {:$literal}

    my %seen{Any};

    multi sub to-ast-native(Hash $_dict!) {
	my $dict = %seen{$_dict};

	unless $dict.defined {
	    $dict = temp %seen{$_dict} = {};
	    $dict{.key} = to-ast(.value) for $_dict.pairs;
	}

	:$dict;
    }

    multi sub to-ast-native(Array $_array!) {
	my $array = %seen{$_array};

	unless $array.defined {
	    $array = temp %seen{$_array} = [ ];
	    $array.push( to-ast( $_ ) ) for $_array.values;
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

	my $date-spec = sprintf "%04d%02d%02d", $dt.year, $dt.month, $dt.day;
	my $time-spec = sprintf "%02d%02d%02d", $dt.hour, $dt.minute, $dt.second;
	my Str $tz-spec = sprintf "%s%02d'%02d'", $tz-sign, $tz-hour, $tz-min;

       [~] "D:", $date-spec, $time-spec, $tz-spec;
    }

    multi sub to-ast-native(DateTime $date-time!) {
	my Str $literal = date-time-formatter($date-time);
	:$literal
    }
    multi sub to-ast-native(Bool $bool!) {:$bool}
    multi sub to-ast-native($other) is default {
        return (:null(Any))
            unless $other.defined;
        die "don't know how to to-ast: {$other.perl}";
    }

    proto sub from-ast(|) is export(:from-ast) {*};

    multi sub from-ast( Pair $p! ) {
        from-ast( |%( $p.kv ) );
    }

    #| for JSON deserialization, e.g. { :int(42) } => :int(42)
    use PDF::Grammar :AST-Types;
    multi sub from-ast( Hash $h! where { .keys == 1 && .keys[0] ∈ AST-Types} ) {
        from-ast( |%$h )
    }

    multi sub from-ast( Array :$array! ) {
        $array
    }

    multi sub from-ast( Bool :$bool! ) {
        $bool;
    }

    multi sub from-ast( Hash :$dict! ) {
        $dict;
    }

    multi sub from-ast( Str :$encoded! ) { $encoded }

    multi sub from-ast( Str :$hex-string! ) { PDF::DAO.coerce( :$hex-string ) }

    multi sub from-ast( Array :$ind-ref! ) {
        :$ind-ref;
    }

    multi sub from-ast( Array :$ind-obj! ) {
        my %content = $ind-obj[2].kv;
        from-ast( |%content )
    }

    multi sub from-ast( Numeric :$int! ) {
        PDF::DAO.coerce :$int;
    }

    multi sub from-ast( Str :$literal! ) { $literal }

    multi sub from-ast( Str :$name! ) {
        PDF::DAO.coerce :$name;
    }

    multi sub from-ast( Numeric :$real! ) {
        PDF::DAO.coerce :$real;
    }

    multi sub from-ast( Hash :$stream! ) {
        $stream;
    }

    multi sub from-ast( $other! where !.isa(Pair) ) {
        return $other
    }

    multi sub from-ast( *@args, *%opt ) is default {
        return Any if %opt<null>:exists;

        die "unexpected from-ast arguments: {[@args].perl}"
            if @args;
        
        die "unable to from-ast {%opt.keys} struct: {%opt.perl}"
    }

}
