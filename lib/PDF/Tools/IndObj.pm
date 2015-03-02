use v6;

class PDF::Tools::IndObj;

use PDF::Object;

has Int $.obj-num;
has Int $.gen-num;
has PDF::Object $.object handles <content>;

#| construct by wrapping a pre-existing PDF::Object
multi submethod BUILD( PDF::Object :$!object!, :$!obj-num, :$!gen-num ) {
}

#| construct an object instance from a PDF::Grammar::PDF ast representation of
#| an indirect object: [ $obj-num, $gen-num, $type => $content ]
multi submethod BUILD( Array :$ind-obj!, :$input, :$type, *%etc ) {
    $!obj-num = $ind-obj[0];
    $!gen-num = $ind-obj[1];
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

    $!object = self.new-object( |%params);
}

multi method new-object( Array :$array!, *%etc) {
    require ::("PDF::Object::Array");
    return ::("PDF::Object::Array").new( :$array, |%etc );
}

multi method new-object( Bool :$bool!, *%etc) {
    require ::("PDF::Object::Bool");
    return ::("PDF::Object::Bool").new( :$bool, |%etc );
}

multi method new-object( Int :$int!, *%etc) {
    require ::("PDF::Object::Num");
    return ::("PDF::Object::Num").new( :$int, |%etc );
}

multi method new-object( Num :$real!, *%etc) {
    require ::("PDF::Object::Num");
    return ::("PDF::Object::Num").new( :$real, |%etc );
}

multi method new-object( Str :$hex-string!, *%etc) {
    require ::("PDF::Object::String");
    return ::("PDF::Object::String").new( :$hex-string, |%etc );
}

multi method new-object( Str :$literal!, *%etc) {
    require ::("PDF::Object::String");
    return ::("PDF::Object::String").new( :$literal, |%etc );
}

multi method new-object( Str :$name!, *%etc) {
    require ::("PDF::Object::Name");
    return ::("PDF::Object::Name").new( :$name, |%etc );
}

multi method new-object( Any :$null!, *%etc) {
    require ::("PDF::Object::Null");
    return ::("PDF::Object::Null").new( :$null, |%etc );
}

multi method new-object( Hash :$dict!, *%etc) {
    require ::("PDF::Object::Dict");
    return ::("PDF::Object::Dict").delegate-class( :$dict ).new( :$dict, |%etc );
}

multi method new-object( Hash :$stream!, *%etc) {
    my %params = %etc;
    for <start end encoded decoded> {
        %params{$_} = $stream{$_}
        if $stream{$_}:exists;
    }
    my $dict = $stream<dict>;
    require ::("PDF::Object::Stream");
    return ::("PDF::Object::Stream").delegate-class( :$dict ).new( :$dict, |%params );
}

#| recreate a PDF::Grammar::PDF / PDF::Writer compatibile ast from the object
method ast {
    :ind-obj[ $.obj-num, $.gen-num, %$.content ]
}

#| create ast for an indirect reference to this object
method ind-ref {
    :ind-ref[ $.obj-num, $.gen-num ]
}

