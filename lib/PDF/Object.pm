use v6;

class PDF::Object {

    multi method compose( Array :$array!, *%etc) {
        require ::("PDF::Object::Array");
        ::("PDF::Object::Array").new( :$array, |%etc);
    }

    multi method compose( Bool :$bool!) {
        require ::("PDF::Object::Bool");
        $bool but ::("PDF::Object::Bool");
    }

    multi method compose( Int :$int!) {
        require ::("PDF::Object::Int");
        $int but ::("PDF::Object::Int");
    }

    multi method compose( Numeric :$real!) {
        require ::("PDF::Object::Real");
        $real but ::("PDF::Object::Real");
    }

    multi method compose( Str :$hex-string!) {
        require ::("PDF::Object::ByteString");

        my Str $str = $hex-string but ::("PDF::Object::ByteString");
        $str.type = 'hex-string';
        $str;
    }

    multi method compose( Str :$literal!) {
        require ::("PDF::Object::ByteString");

        my Str $str = $literal but ::("PDF::Object::ByteString");
        $str.type = 'literal';
        $str;
    }

    multi method compose( Str :$name!) {
        require ::("PDF::Object::Name");
        $name but ::("PDF::Object::Name");
    }

    multi method compose( Any :$null!) {
        require ::("PDF::Object::Null");
        ::("PDF::Object::Null").new;
    }

    multi method compose( Hash :$dict!, *%etc) {
        require ::("PDF::Object::Dict");
	my $fallback = ::("PDF::Object::Dict");
        $.delegate( :$dict, :$fallback ).new( :$dict, |%etc );
    }

    multi method compose( Hash :$stream!, *%etc) {
        my %params = %etc;
        for <start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my Hash $dict = $stream<dict> // {};
        require ::("PDF::Object::Stream");
	my $fallback = ::("PDF::Object::Stream");
        my $stream-delegate =  $.delegate( :$dict, :$fallback );
        $stream-delegate.new( :$dict, |%params );
    }

    proto sub to-ast(|) is export(:to-ast) {*};
    multi sub to-ast(Pair $p!) {$p}
    multi sub to-ast(PDF::Object $object!) {$object.content}
    multi sub to-ast($other!) is default {
        to-ast-native $other
    }
    proto sub to-ast-native(|) is export(:to-ast-native) {*};
    multi sub to-ast-native(Int $int!) {:$int}
    multi sub to-ast-native(Numeric $real!) {:$real}
    multi sub to-ast-native(Hash $_dict!) {
        my %dict = %( $_dict.pairs.map( -> $kv { $kv.key => to-ast($kv.value) } ) );
        :%dict;
    }
    multi sub to-ast-native(Array $_array!) {
        my @array = $_array.map({ to-ast( $_ ) });
        :@array;
    }
    multi sub to-ast-native(Str $literal!) {:$literal}
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
    multi sub from-ast( Hash $h! where { .keys == 1 && .keys[0] ~~ /^<[a..z]>/} ) {
        from-ast( |%$h )
    }

    multi sub from-ast( Array :$array! ) {
        $array
    }

    multi sub from-ast( Bool :$bool! ) {
        $bool;
    }

    multi sub from-ast( Hash :$dict!, :$keys ) {
        $dict;
    }

    multi sub from-ast( Str :$encoded! ) { $encoded }

    multi sub from-ast( Str :$hex-string! ) { PDF::Object.compose( :$hex-string ) }

    multi sub from-ast( Array :$ind-ref! ) {
        :$ind-ref;
    }

    multi sub from-ast( Array :$ind-obj! ) {
        my %content = $ind-obj[2].kv;
        from-ast( |%content )
    }

    multi sub from-ast( Numeric :$int! ) {
        PDF::Object.compose :$int;
    }

    multi sub from-ast( Str :$literal! ) { $literal }

    multi sub from-ast( Str :$name! ) {
        PDF::Object.compose :$name;
    }

    multi sub from-ast( Numeric :$real! ) {
        PDF::Object.compose :$real;
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

    BEGIN our @class-path = ();
    our %handler;

    method add-class-path(Str $dom-class!) {
        @class-path.unshift( $dom-class )
            unless @class-path && @class-path[0] eq $dom-class;
        @class-path;
    }

    multi method install-delegate( :$type!, :$subtype, :$handler-class! ) {
        my Str $subclass = $subtype
            ?? [~] $type, '::', $subtype
            !! $type;
        self.install-delegate( :$subclass, :$handler-class );
    }

    multi method install-delegate( :$subclass!, :$handler-class ) {
        %handler{$subclass} = $handler-class;
    }

    multi method find-delegate( :$type!, :$subtype!, :$fallback!) {
        my Str $subclass = $subtype
            ?? [~] $type, '::', $subtype
            !! $type;
        self.find-delegate( :$subclass, :$fallback );
    }

    multi method find-delegate( :$subclass! where { %handler{$_}:exists } ) {
        %handler{$subclass}
    }

    multi method find-delegate( :$subclass!, :$fallback! ) is default {

        my $handler-class = $fallback;
        my $resolved;

        for @class-path, 'PDF::Object::Type' -> $dom-class {

            try {
		require ::($dom-class)::($subclass);
		$handler-class = ::($dom-class)::($subclass);
		$resolved = True;
		last;
	    }
		
        }

        unless $resolved {
            warn "unable to load DOM subclass {$subclass} in paths: @class-path[] PDF::Object::Type"
                if @class-path;
        }

        self.install-delegate( :$subclass, :$handler-class );
    }

    multi method delegate( Hash :$dict! where {$dict<Type>:exists}, :$fallback) {
	my $type = from-ast($dict<Type>);
	my $subtype = from-ast($dict<Subtype> // $dict<S>);
	$.find-delegate( :$type, :$subtype, :$fallback );
    }

    multi method delegate( :$fallback! ) is default {
	$fallback;
    }

    #| unique identifier for this object instance
    method id { ~ self.WHICH }

}
