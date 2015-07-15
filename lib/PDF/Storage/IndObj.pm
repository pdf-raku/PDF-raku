use v6;

class PDF::Storage::IndObj {

    use PDF::Object;

    has Int $.obj-num;
    has Int $.gen-num;
    has $.object handles <content>;

    #| construct by wrapping a pre-existing PDF::Object
    multi submethod BUILD( PDF::Object :$!object!, :$!obj-num, :$!gen-num ) {
    }

    #| construct an object instance from a PDF::Grammar::PDF ast representation of
    #| an indirect object: [ $obj-num, $gen-num, $type => $content ]
    multi submethod BUILD( Array :$ind-obj!, :$input, :$type, :$reader, *%etc ) {
        $!obj-num = $ind-obj[0];
        $!gen-num = $ind-obj[1];
        my %params = $ind-obj[2].kv, %etc;
        %params<input> = $input
            if $input.defined;

        if $type.defined {
            # cross check the actual vs expected type of the object
            my Str $actual-type = (%params<stream> //%params)<dict><Type>.value // '??';
            die "expected object of Type $type, but /Type is missing"
                unless $actual-type.defined;
            die "expected object of Type $type, got $actual-type"
                unless $actual-type eq $type
        }

        $!object = PDF::Object.compose( :$reader, :$!obj-num, :$!gen-num, |%params);
    }

    #| recreate a PDF::Grammar::PDF / PDF::Writer compatibile ast from the object
    method ast returns Pair {
        :ind-obj[ $.obj-num, $.gen-num, %$.content ]
    }

    #| create ast for an indirect reference to this object
    method ind-ref returns Pair {
        :ind-ref[ $.obj-num, $.gen-num ]
    }

}
