use v6;

class PDF::Basic::Object;

has Str $.input;  # raw PDF image (latin-1 encoding)
has Hash %.ind-obj-idx;

submethod BUILD(Hash :$root, Str :$!input) {

    if $root.defined {
        for $root<body>.list  {
            #= build object index
            for <objects>.list {
                next unless my $ind-obj = .<ind-obj>;
                my $obj = $ind-obj[0].Int;
                my $gen = $ind-obj[1].Int;
                %!ind-obj-idx{$obj}{$gen} = $ind-obj;
            }
        }
    }
}

# unbox convert PDF objects to native Perl structs
# - only supports a subset of token types

our proto method unbox(*%) {*}

multi method unbox( Array :$array! ) {
    [ $array.map: { $.unbox( |%( .kv )) } ];
}

multi method unbox( Bool :$bool! ) {
    $bool;
}

multi method unbox( Hash :$dict! ) {
    my %hash = $dict.keys.map: { $_ => $.unbox( |%( $dict{$_}.kv )) };
    %hash;
}

multi method unbox( Str :$hex-string! ) { $hex-string }

multi method unbox( Array :$ind-ref! ) {

    # dereference
    my $obj = $ind-ref[0].Int;
    my $gen = $ind-ref[1].Int;

    my $ind-obj = %.ind-obj-idx{$obj}{$gen}
        or die "unresolved indirect object reference: obj-num:$obj  gen:$gen";

    $.unbox( |%$ind-obj );
}

multi method unbox( Array :$ind-obj! ) {
    # hmm, throw array trailing objects?
    my %first-obj = $ind-obj[2].kv;
    $.unbox( |%first-obj )
}

multi method unbox( Numeric :$int! ) { $int.Int }

multi method unbox( Str :$literal! ) { $literal }

multi method unbox( Str :$name! ) { $name }

multi method unbox( Any :$null! ) { $null }

multi method unbox( Numeric :$real! ) { $real }

multi method unbox( *@args, *%opts ) is default {

    die "unexpected unbox arguments: {[@args].perl}"
        if @args;
        
    die "unable to unbox {%opts.keys} struct: {%opts.perl}"
}
