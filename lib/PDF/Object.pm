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

        my $str = $hex-string but ::("PDF::Object::ByteString");
        $str.type = 'hex-string';
        $str;
    }

    multi method compose( Str :$literal!) {
        require ::("PDF::Object::ByteString");

        my $str = $literal but ::("PDF::Object::ByteString");
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
        return ::("PDF::Object::Dict").delegate( :$dict ).new( :$dict, |%etc );
    }

    multi method compose( Hash :$stream!, *%etc) {
        my %params = %etc;
        for <start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my $dict = $stream<dict> // {};
        if $dict<Type>:exists {
            require ::("PDF::Object::Stream");
            return ::("PDF::Object::Stream").delegate( :$dict ).new( :$dict, |%params );
        }
        else {
            # Assume Content when there's no /Type entry in the dictionary
            require ::("PDF::Object::Content");
            return ::("PDF::Object::Content").new( :$dict, |%params );
        }
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
        return :null(Any)
            unless $other.defined;
        die "don't know how to to-ast: {$other.perl}";
    }

    proto sub from-ast(|) is export(:from-ast) {*};

    multi sub from-ast( Pair $p! ) {
        from-ast( |%( $p.kv ) );
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

    multi sub from-ast( Str :$hex-string! ) { $hex-string }

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

    method finish {}

}
