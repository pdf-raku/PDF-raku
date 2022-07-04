use v6;

module PDF::COS::Util {

    use PDF::COS;

    proto sub to-ast(|) is export(:to-ast) {*};
    multi sub to-ast(Pair $p!) {$p}
    multi sub to-ast(PDF::COS $object!) { $object.content }
    multi sub to-ast($other!) { ast-coerce $other }
    proto sub ast-coerce(|) is export(:ast-coerce) {*};
    multi sub ast-coerce(Numeric:D $_) { $_ }
    multi sub ast-coerce(Str:D $literal!)  { :$literal }

    my Lock $lock .= new;
    my %seen{Any};

    multi sub ast-coerce(Hash:D $_hash!) {
        my $init;
        my $dict = $lock.protect: {
            %seen{$_hash} //= do {
                $init = True;
                %()
            }
        }
        if $init {
            LEAVE $lock.protect: { %seen{$_hash}:delete }
    	    $dict{.key} = to-ast(.value)
                for $_hash.pairs;
        }
        :$dict;
    }

    multi sub ast-coerce(array:D $a) {
        $a.of ~~ Str
            ?? :array[ $a.map( -> $literal { :$literal }) ]
            !! array => $a.Array;
    }

    multi sub ast-coerce(List:D $a where .of ~~ Numeric) {
        array => $a.Array;
    }

    multi sub ast-coerce(List:D $_list!) {
        my $init;
	my $array = $lock.protect: {
            %seen{$_list} //= do {
                $init = True;
                [];
            }
        }
        if $init {
            LEAVE $lock.protect: { %seen{$_list}:delete }
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

       [~] 'D:', $date-spec, $time-spec, $tz-spec;
    }

    multi sub ast-coerce(DateTime:D $date-time!) {
	my Str $literal = date-time-formatter($date-time);
	:$literal
    }
    multi sub ast-coerce(Any:U) {Any}
    multi sub ast-coerce(Any:D $_) {
        die "don't know how to ast-coerce: {.raku}";
    }
    multi sub ast-coerce(Enumeration $_) is default { ast-coerce(.value) }

    proto sub from-ast(|) is export(:from-ast) {*};

    multi sub from-ast( Pair $_) {
        .value ~~ Enumeration
            ?? from-ast( |.key => .value.value )
            !! from-ast( |$_ );
    }

    #| for JSON deserialization, e.g. { :int(42) } => :int(42)
    use PDF::Grammar:ver(v0.1.0+) :AST-Types;
    BEGIN my %ast-types = AST-Types.enums;
    multi sub from-ast( Hash $h! where { .keys == 1 && (%ast-types{.keys[0]}:exists)} ) {
        from-ast( |$h )
    }

    multi sub from-ast( $other!)            { $other }

    multi sub from-ast( Array :$array! )    { $array }

    multi sub from-ast( Hash :$dict! )      { $dict }

    multi sub from-ast( Str :$encoded! )    { $encoded }

    multi sub from-ast( Str :$hex-string! ) { PDF::COS.coerce :$hex-string }

    multi sub from-ast( Array :$ind-ref! )  { :$ind-ref }

    multi sub from-ast( Array :$ind-obj! )  { from-ast |$ind-obj[2].kv }

    multi sub from-ast( Str :$literal! )    { PDF::COS.coerce :$literal }

    multi sub from-ast( Str :$name! )       { PDF::COS.coerce :$name }

    multi sub from-ast( Hash :$stream! )    { $stream }

    # Pre PDF v0.5.8 compatibility; needed for older JSON files
    multi sub from-ast( Bool :$bool! )      { $bool }
    multi sub from-ast( Numeric :$int! )    { $int }
    multi sub from-ast( Numeric :$real! )   { $real }
    multi sub from-ast( :$null! )           { Any }

    multi sub from-ast( *@args, *%opt ) {
        if @args -> $_ {
            die "unexpected from-ast arguments: {.raku}"
        }
        die "unable to from-ast {%opt.keys} struct: {%opt.raku}"
    }

    sub flag-is-set(uint $mask, uint8 $flag-num) is export(:flag-is-set) {
	my \bit = 1 +< ($flag-num - 1);
	? ($mask +& bit);
    }
}

