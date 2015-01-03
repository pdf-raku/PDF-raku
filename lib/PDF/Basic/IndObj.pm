use v6;

class PDF::Basic::IndObj;

has Int $.obj-num;
has Int $.gen-num;

#| construct and object instancefrom a PDF::Grammar::PDF ast representation of
#| an indirect object: [ $obj-num, $gen-num, $type => $content ]
multi method indobj-new( Array :$ind-obj!, :$input ) {
    my $obj-num = $ind-obj[0];
    my $gen-num = $ind-obj[1];
    my $type = $ind-obj[2].key;
    my %params = $ind-obj[2].value.kv;
    %params<input> = $input
        if $input.defined;

    $.indobj-new( $type, :$obj-num, :$gen-num, |%params);
}

multi method indobj-new( 'stream', *%params) {
    require ::("PDF::Basic::IndObj::Stream");
    return ::("PDF::Basic::IndObj::Stream").indobj-new( |%params );
}
