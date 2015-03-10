use v6;

class PDF::Object {

    method serialize {
        die "root object must be a dictionary object with a /Type entry"
            unless self.isa(Hash) && (self<Type>:exists);
        require ::('PDF::Tools::Serializer');
        my $serializer = ::('PDF::Tools::Serializer').new;
        my $root = $serializer.freeze( self );
        my $objects = $serializer.ind-objs;
        return %( :$root, :$objects );
    }

    multi method compose( Array :$array!) {
        require ::("PDF::Object::Array");
        return $array but ::("PDF::Object::Array");
    }

    multi method compose( Bool :$bool!) {
        require ::("PDF::Object::Bool");
        return $bool but ::("PDF::Object::Bool");
    }

    multi method compose( Int :$int!) {
        require ::("PDF::Object::Int");
        $int but  ::("PDF::Object::Int");
    }

    multi method compose( Numeric :$real!) {
        require ::("PDF::Object::Real");
        $real but ::("PDF::Object::Real");
    }

    multi method compose( Str :$hex-string!) {
        require ::("PDF::Object::String");

        my $str = $hex-string but ::("PDF::Object::String");
        $str.type = 'hex-string';
        $str;
    }

    multi method compose( Str :$literal!) {
        require ::("PDF::Object::String");

        my $str = $literal but ::("PDF::Object::String");
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
        my %dict = %( to-obj :$dict );
        require ::("PDF::Object::Dict");
        return ::("PDF::Object::Dict").delegate( :%dict ).new( :%dict, |%etc );
    }

    multi method compose( Hash :$stream!, *%etc) {
        my %params = %etc;
        for <start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my $dict = to-obj :dict($stream<dict> // {});
        require ::("PDF::Object::Stream");
        return ::("PDF::Object::Stream").delegate( :$dict ).new( :$dict, |%params );
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

    proto sub to-obj(|) is export(:to-obj) {*};

    multi sub to-obj( Pair $p! ) {
        to-obj( |%( $p.kv ) );
    }

    multi sub to-obj( Hash $h! ) {
        to-obj( |%( $h ) );
    }

    multi sub to-obj( Array :$array! ) {
        [ $array.map: { to-obj( $_ ) } ];
    }

    multi sub to-obj( Bool :$bool! ) {
        $bool;
    }

    multi sub to-obj( Hash :$dict!, :$keys ) {
        my @keys = $keys.defined
            ?? $keys.grep: {$dict{$_}:exists}
        !! $dict.keys;
        my %hash = @keys.map: { $_ => to-obj( $dict{$_} ) };
        %hash.item;
    }

    multi sub to-obj( Str :$hex-string! ) { $hex-string }

    multi sub to-obj( Array :$ind-ref! ) {

        :$ind-ref;
    }

    multi sub to-obj( Array :$ind-obj! ) {
        my %content = $ind-obj[2].kv;
        to-obj( |%content )
    }

    multi sub to-obj( Numeric :$int! ) {
        PDF::Object.compose :$int;
    }

    multi sub to-obj( Str :$literal! ) { $literal }

    multi sub to-obj( Str :$name! ) {
        PDF::Object.compose :$name;
    }

    multi sub to-obj( Numeric :$real! ) {
        PDF::Object.compose :$real;
    }

    multi sub to-obj( Hash :$stream! ) {
        my $dict = $stream<dict>;
        my %stream = %$stream, dict => to-obj( :$dict );
        %stream;
    }

    multi sub to-obj( $other! where !.isa(Pair) ) {
        return $other
    }

    multi sub to-obj( *@args, *%opt ) is default {
        return Any if %opt<null>:exists;

        die "unexpected to-obj arguments: {[@args].perl}"
            if @args;
        
        die "unable to to-obj {%opt.keys} struct: {%opt.perl}"
    }

}
