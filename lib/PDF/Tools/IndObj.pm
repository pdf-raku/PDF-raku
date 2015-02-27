use v6;

class PDF::Tools::IndObj;

has Int $.obj-num is rw;
has Int $.gen-num is rw;

#| construct an object instance from a PDF::Grammar::PDF ast representation of
#| an indirect object: [ $obj-num, $gen-num, $type => $content ]
multi method new-delegate( Array :$ind-obj!, :$input, :$type, *%etc ) {
    my $obj-num = $ind-obj[0];
    my $gen-num = $ind-obj[1];
    my %params = $ind-obj[2].kv, %etc;
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

multi method new-delegate( Array :$array!, *%etc) {
    require ::("PDF::Tools::IndObj::Array");
    return ::("PDF::Tools::IndObj::Array").new( :$array, |%etc );
}

multi method new-delegate( Bool :$bool!, *%etc) {
    require ::("PDF::Tools::IndObj::Bool");
    return ::("PDF::Tools::IndObj::Bool").new( :$bool, |%etc );
}

multi method new-delegate( Int :$int!, *%etc) {
    require ::("PDF::Tools::IndObj::Num");
    return ::("PDF::Tools::IndObj::Num").new( :$int, |%etc );
}

multi method new-delegate( Num :$real!, *%etc) {
    require ::("PDF::Tools::IndObj::Num");
    return ::("PDF::Tools::IndObj::Num").new( :$real, |%etc );
}

multi method new-delegate( Str :$hex-string!, *%etc) {
    require ::("PDF::Tools::IndObj::String");
    return ::("PDF::Tools::IndObj::String").new( :$hex-string, |%etc );
}

multi method new-delegate( Str :$literal!, *%etc) {
    require ::("PDF::Tools::IndObj::String");
    return ::("PDF::Tools::IndObj::String").new( :$literal, |%etc );
}

multi method new-delegate( Str :$name!, *%etc) {
    require ::("PDF::Tools::IndObj::Name");
    return ::("PDF::Tools::IndObj::Name").new( :$name, |%etc );
}

multi method new-delegate( Any :$null!, *%etc) {
    require ::("PDF::Tools::IndObj::Null");
    return ::("PDF::Tools::IndObj::Null").new( :$null, |%etc );
}

multi method new-delegate( Hash :$dict!, *%etc) {
    require ::("PDF::Tools::IndObj::Dict");
    return ::("PDF::Tools::IndObj::Dict").new-delegate( :$dict, |%etc );
}

multi method new-delegate( Hash :$stream!, *%etc) {
    require ::("PDF::Tools::IndObj::Stream");
    return ::("PDF::Tools::IndObj::Stream").new-delegate( :$stream, |%etc );
}

#| recreate a PDF::Grammar::PDF / PDF::Writer compatibile ast from the object
method ast {
    :ind-obj[ $.obj-num, $.gen-num, %$.content ]
}

#| create ast for an indirect reference to this object
method ind-ref {
    :ind-ref[ $.obj-num, $.gen-num ]
}

