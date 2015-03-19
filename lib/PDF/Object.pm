use v6;

class PDF::Object {

    method serialize {
        require ::('PDF::Tools::Serializer');
        my $serializer = ::('PDF::Tools::Serializer').new;
        $serializer.analyse( self );
        my $root = $serializer.freeze( self, :is-root );
        my $objects = $serializer.ind-objs;
        $.post-process( $objects );
        return %( :$root, :$objects );
    }

    #| insert Parent indirect references, etc
    method post-process( Array $ind-objs is rw) {
        for $ind-objs.list -> $ind-obj {
            next unless $ind-obj.key eq 'ind-obj' && $ind-obj.value[2].key eq 'dict';
            my $dict = $ind-obj.value[2].value;

            if $dict<Kids>:exists {
                my $obj-num = $ind-obj.value[0];
                for $dict<Kids>.value.list -> $kid {
                    if $kid.key eq 'ind-ref' {
                        my $ref-obj-num = $kid.value[0];
                        # assumes that objects are consectively numbered 1, 2, ...
                        my $ref-object = $ind-objs[ $ref-obj-num - 1].value;
                        die "objects out of sequence: $ref-obj-num => {$ref-object.perl}"
                            unless $ref-object[0] == $ref-obj-num
                            && $ref-object[1] == 0 # gen-num
                            && $ref-object[2].key eq 'dict'; # sanity

                        $ref-object[2].value<Parent> = :ind-ref[ $obj-num, 0];
                    }
                }
            }
        }
    }

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
        my %hash;
        %hash{.key} = to-obj( .value )
            for $h.pairs;
        %hash.item;
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
