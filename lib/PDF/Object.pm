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
    multi method coerce(Hash $dict!, :$reader) {
	$.coerce( :$dict, :$reader )
    }
    multi method coerce(Array $array!, :$reader) {
        $.coerce( :$array, :$reader )
    }

    multi method coerce( Array :$array!, *%etc) {
        require ::("PDF::Object::Array");
        my $fallback = ::("PDF::Object::Array");
        $.delegate( :$array, :$fallback ).new( :$array, |%etc );
    }

    multi method coerce( Bool :$bool!) {
        require ::("PDF::Object::Bool");
        $bool but ::("PDF::Object::Bool");
    }

    multi method coerce( Int :$int!) {
        require ::("PDF::Object::Int");
        $int but ::("PDF::Object::Int");
    }

    multi method coerce( Numeric :$real!) {
        require ::("PDF::Object::Real");
        $real but ::("PDF::Object::Real");
    }

    multi method coerce( Str :$hex-string!) {
        require ::("PDF::Object::ByteString");

        my Str $str = $hex-string but ::("PDF::Object::ByteString");
        $str.type = 'hex-string';
        $str;
    }

    multi method coerce( Str :$literal!) {
        require ::("PDF::Object::ByteString");

        my Str $str = $literal but ::("PDF::Object::ByteString");
        $str.type = 'literal';
        $str;
    }

    multi method coerce( Str :$name!) {
        require ::("PDF::Object::Name");
        $name but ::("PDF::Object::Name");
    }

    multi method coerce( Any :$null!) {
        require ::("PDF::Object::Null");
        ::("PDF::Object::Null").new;
    }

    multi method coerce( Hash :$dict!, *%etc) {
        require ::("PDF::Object::Dict");
	my $class = ::("PDF::Object::Dict");
	$class = $.delegate( :$dict, :fallback($class) );
	$class.new( :$dict, |%etc );
    }

    multi method coerce( Hash :$stream!, *%etc) {
        my %params = %etc;
        for <start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my Hash $dict = $stream<dict> // {};
        require ::("PDF::Object::Stream");
	my $class = ::("PDF::Object::Stream");
	$class = $.delegate( :$dict, :fallback($class) );
        $class.new( :$dict, |%params );
    }

    multi method coerce($val) is default { $val }

    our $delegator;
    method delegator is rw { $delegator }
    method delegate(*%opt) {
	unless $delegator.can('delegate') {
	    require ::('PDF::Object::Delegator');
	    $delegator = ::('PDF::Object::Delegator');
	}
	$delegator.delegate(|%opt);
    }

    #| unique identifier for this object instance
    method id { ~ self.WHICH }

}
