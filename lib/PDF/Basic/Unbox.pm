use v6;

class PDF::Basic::Unbox;

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
    my $obj-num = $ind-ref[0].Int;
    my $gen-num = $ind-ref[1].Int;

    my $ind-obj = %.ind-obj-idx{$obj-num}{$gen-num}
    // return;

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
