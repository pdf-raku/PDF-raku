use v6;

class PDF::Tools::IndObj;

has Int $.obj-num is rw;
has Int $.gen-num is rw;

#| construct and object instancefrom a PDF::Grammar::PDF ast representation of
#| an indirect object: [ $obj-num, $gen-num, $type => $content ]
multi method new-delegate( Array :$ind-obj!, :$input, :$type, *%p ) {
    my $obj-num = $ind-obj[0];
    my $gen-num = $ind-obj[1];
    my %params = $ind-obj[2].kv, %p;
    %params<input> = $input
        if $input.defined;

    if $type.defined {
        # cross check the actual vs expected type of the object
        my $actual-type = (%params<stream> //%params)<dict><Type>.value // '??';
        die "expected object of Type $type, but /Type is missing"
            unless $actual-type.defined;
        die "expected object of Type $type, got $actual-type"
            unless $actual-type eq $type
    }

    $.new-delegate( :$obj-num, :$gen-num, |%params);
}

multi method new-delegate( Array :$array!, *%params) {
    require ::("PDF::Tools::IndObj::Array");
    return ::("PDF::Tools::IndObj::Array").new( :$array, |%params );
}

multi method new-delegate( Bool :$bool!, *%params) {
    require ::("PDF::Tools::IndObj::Bool");
    return ::("PDF::Tools::IndObj::Bool").new( :$bool, |%params );
}

multi method new-delegate( Int :$int!, *%params) {
    require ::("PDF::Tools::IndObj::Num");
    return ::("PDF::Tools::IndObj::Num").new( :$int, |%params );
}

multi method new-delegate( Num :$real!, *%params) {
    require ::("PDF::Tools::IndObj::Num");
    return ::("PDF::Tools::IndObj::Num").new( :$real, |%params );
}

multi method new-delegate( Str :$hex-string!, *%params) {
    require ::("PDF::Tools::IndObj::String");
    return ::("PDF::Tools::IndObj::String").new( :$hex-string, |%params );
}

multi method new-delegate( Str :$literal!, *%params) {
    require ::("PDF::Tools::IndObj::String");
    return ::("PDF::Tools::IndObj::String").new( :$literal, |%params );
}

multi method new-delegate( Str :$name!, *%params) {
    require ::("PDF::Tools::IndObj::Name");
    return ::("PDF::Tools::IndObj::Name").new( :$name, |%params );
}

multi method new-delegate( Any :$null!, *%params) {
    require ::("PDF::Tools::IndObj::Null");
    return ::("PDF::Tools::IndObj::Null").new( :$null, |%params );
}

multi method new-delegate( Hash :$dict!, *%params) {
    require ::("PDF::Tools::IndObj::Dict");
    return ::("PDF::Tools::IndObj::Dict").new-delegate( :$dict, |%params );
}

multi method new-delegate( Hash :$stream!, *%params) {
    require ::("PDF::Tools::IndObj::Stream");
    return ::("PDF::Tools::IndObj::Stream").new-delegate( :$stream, |%params );
}

method ast {
    :ind-obj[ $.obj-num, $.gen-num, %$.content ]
}

method ind-ref {
    :ind-ref[ $.obj-num, $.gen-num ]
}

