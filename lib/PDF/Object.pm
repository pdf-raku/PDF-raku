use v6;

class PDF::Object {

    method serialize {
        require ::('PDF::Tools::Serializer');
        my $serializer = ::('PDF::Tools::Serializer').new;
        my $root = $serializer.freeze( self );
        my $objects =  $serializer.ind-objs;
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
        my %dict = %( unbox :$dict );
        require ::("PDF::Object::Dict");
        return ::("PDF::Object::Dict").delegate-class( :%dict ).new( :%dict, |%etc );
    }

    multi method compose( Hash :$stream!, *%etc) {
        my %params = %etc;
        for <start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my $dict = unbox :dict($stream<dict> // {});
        require ::("PDF::Object::Stream");
        return ::("PDF::Object::Stream").delegate-class( :$dict ).new( :$dict, |%params );
    }

    proto sub box(|) is export(:box) {*};
    multi sub box(Pair $p!) {$p}
    multi sub box(PDF::Object $object!) {$object.content}
    multi sub box($other!) is default {
        box-native $other
    }
    proto sub box-native(|) {*};
    multi sub box-native(Int $int!) {:$int}
    multi sub box-native(Numeric $real!) {:$real}
    multi sub box-native(Hash $_dict!) {
        my %dict = %( $_dict.pairs.map( -> $kv { $kv.key => box($kv.value) } ) );
        :%dict;
    }
    multi sub box-native(Array $_array!) {
        my @array = $_array.map({ box( $_ ) });
        :@array;
    }
    multi sub box-native(Str $literal!) {:$literal}
    multi sub box-native(Bool $bool!) {:$bool}
    multi sub box-native($other) is default {
        return :null(Any)
            unless $other.defined;
        die "don't know how to box: {$other.perl}";
    }

    proto sub unbox(|) is export(:unbox) {*};

    multi sub unbox( Pair $p! ) {
        unbox( |%( $p.kv ) );
    }

    multi sub unbox( Hash $h! ) {
        unbox( |%( $h ) );
    }

    multi sub unbox( Array :$array! ) {
        [ $array.map: { unbox( $_ ) } ];
    }

    multi sub unbox( Bool :$bool! ) {
        $bool;
    }

    multi sub unbox( Hash :$dict!, :$keys ) {
        my @keys = $keys.defined
            ?? $keys.grep: {$dict{$_}:exists}
        !! $dict.keys;
        my %hash = @keys.map: { $_ => unbox( $dict{$_} ) };
        %hash.item;
    }

    multi sub unbox( Str :$hex-string! ) { $hex-string }

    multi sub unbox( Array :$ind-ref! ) {

        :$ind-ref;
    }

    multi sub unbox( Array :$ind-obj! ) {
        my %content = $ind-obj[2].kv;
        unbox( |%content )
    }

    multi sub unbox( Numeric :$int! ) {
        PDF::Object.compose :$int;
    }

    multi sub unbox( Str :$literal! ) { $literal }

    multi sub unbox( Str :$name! ) {
        PDF::Object.compose :$name;
    }

    multi sub unbox( Numeric :$real! ) {
        PDF::Object.compose :$real;
    }

    multi sub unbox( Hash :$stream! ) {
        my $dict = $stream<dict>;
        my %stream = %$stream, dict => unbox( :$dict );
        %stream;
    }

    multi sub unbox( $other! where !.isa(Pair) ) {
        return $other
    }

    multi sub unbox( *@args, *%opt ) is default {
        return Any if %opt<null>:exists;

        die "unexpected unbox arguments: {[@args].perl}"
            if @args;
        
        die "unable to unbox {%opt.keys} struct: {%opt.perl}"
    }

}
