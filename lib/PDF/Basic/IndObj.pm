use v6;

class PDF::Basic::IndObj;

has Int $obj-num;
has Int $gen-num;

multi method indobj-new( Hash :$dict, *%params) {
    # it's a stream of some sort
    require ::("PDF::Basic::IndObj::Stream");
    return ::("PDF::Basic::IndObj::Stream").indobj-new( :$dict, |%params );
}

multi method indobj-new( *%params ) is default {
    die "unable to construct indirect object: {%params.perl}";
}
