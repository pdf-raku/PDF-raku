use v6;

class PDF::Object {

    proto method is-indirect-type(|c --> Bool) {*}

    multi method is-indirect-type(Hash $dict!) {
	? <Type FunctionType PatternType ShadingType>.first({$dict{$_}:exists});
    }

    #| tba
    multi method is-indirect-type(Array $array) {
	Mu
    }

    multi method is-indirect-type($) {
	False
    }				    

    # coerce Hash & Array assignments to objects
    multi method coerce(PDF::Object $val!) { $val }
    #| to allow round-tripping from JSON

    multi method coerce(Hash $dict!, |c) {
	use PDF::Grammar :AST-Types;
	+$dict == 1 && $dict.keys[0] ∈ AST-Types
	    ?? $.coerce( |%$dict, |c )    #| JSON munged pair
	    !! $.coerce( :$dict,  |c );
    }
    multi method coerce(Array $array!, |c) {
        $.coerce( :$array, |c )
    }
    multi method coerce(DateTime $dt, |c) {
	$.delegator.coerce( $dt, DateTime, |c)
    }
    multi method coerce(Pair $_!, |c) {
	$.coerce( |%$_, |c)
    }
    method add-role($obj, Str $role) {
	require ::($role);
        $obj does ::($role)
	    unless $obj.does(::($role));
	$obj;
    }

    multi method coerce( Array :$array!, |c ) {
        require ::("PDF::Object::Array");
        my $fallback = ::("PDF::Object::Array");
        $.delegate( :$array, :$fallback ).new( :$array, |c );
    }

    multi method coerce( Bool :$bool!) {
        $.add-role($bool, "PDF::Object::Bool");
    }

    multi method coerce( Array :$ind-ref!) {
	:$ind-ref
    }

    multi method coerce( Int :$int!) {
        $.add-role($int, "PDF::Object::Int");
    }

    multi method coerce( Numeric :$real!) {
        $.add-role($real, "PDF::Object::Real");
    }

    multi method coerce( Str :$hex-string!) {
        $.add-role($hex-string, "PDF::Object::ByteString");
        $hex-string.type = 'hex-string';
        $hex-string;
    }

    multi method coerce( Str :$literal!) {
        $.add-role( $literal, "PDF::Object::ByteString");
        $literal.type = 'literal';
        $literal;
    }

    multi method coerce( Str :$name!) {
        $.add-role($name, "PDF::Object::Name");
    }

    multi method coerce( Any :$null!) {
        require ::("PDF::Object::Null");
        ::("PDF::Object::Null").new;
    }

    multi method coerce( Hash :$dict!, |c ) {
        require ::("PDF::Object::Dict");
	my $class = ::("PDF::Object::Dict");
	$class = $.delegate( :$dict, :fallback($class) );
	$class.new( :$dict, |c );
    }

    multi method coerce( Hash :$stream!, |c ) {
        my %params;
        for <start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my Hash $dict = $stream<dict> // {};
        require ::("PDF::Object::Stream");
	my $class = ::("PDF::Object::Stream");
	$class = $.delegate( :$dict, :fallback($class) );
        $class.new( :$dict, |%params, |c );
    }

    multi method coerce($val) is default { $val }

    our $delegator;
    method delegator is rw {
	unless $delegator.can('delegate') {
	    require ::('PDF::Object::Delegator');
	    $delegator = ::('PDF::Object::Delegator');
	}
	$delegator
    }
    method delegate(|c) {
	$.delegator.delegate(|c);
    }

    #| unique identifier for this object instance
    method id { ~ self.WHICH }

}
