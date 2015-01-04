use v6;

class PDF::Basic::IndObj;

has Int $.obj-num is rw;
has Int $.gen-num is rw;

#| construct and object instancefrom a PDF::Grammar::PDF ast representation of
#| an indirect object: [ $obj-num, $gen-num, $type => $content ]
multi method indobj-new( Array :$ind-obj!, :$input ) {
     my $obj-num = $ind-obj[0];
    my $gen-num = $ind-obj[1];
    my %params = $ind-obj[2].kv;
    %params<input> = $input
        if $input.defined;

    $.indobj-new( :$obj-num, :$gen-num, |%params);
}

multi method indobj-new( Array :$array!, *%params) {
    require ::("PDF::Basic::IndObj::Array");
    return ::("PDF::Basic::IndObj::Array").indobj-new( :$array, |%params );
}

multi method indobj-new( Hash :$stream!, *%params) {
    require ::("PDF::Basic::IndObj::Stream");
    return ::("PDF::Basic::IndObj::Stream").indobj-new( :$stream, |%params );
}

method ast {
    :ind-obj[ $.obj-num, $.gen-num, %$.content ]
}
