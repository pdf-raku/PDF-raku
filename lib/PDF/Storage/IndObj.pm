use v6;

class PDF::Storage::IndObj {

    use PDF::DAO;

    has Int $.obj-num;   #| positive object number, 0 for trailer, or -1 to force renumbering
    has UInt $.gen-num;
    has $.object handles <content>;

    #| construct by wrapping a pre-existing PDF::DAO
    multi submethod BUILD( PDF::DAO :$!object!, :$!obj-num, :$!gen-num ) {
    }

    #| construct an object instance from a PDF::Grammar::PDF ast representation of
    #| an indirect object: [ $obj-num, $gen-num, $type => $content ]
    multi submethod BUILD( Array :$ind-obj!, |c ) {
        $!obj-num = $ind-obj[0];
        $!gen-num = $ind-obj[1];
        my $ast = $ind-obj[2];

        $!object = PDF::DAO.coerce( :$!obj-num, :$!gen-num, |%$ast, |c );
    }

    #| recreate a PDF::Grammar::PDF / PDF::Writer compatibile ast from the object
    method ast returns Pair {
        :ind-obj[ $.obj-num, $.gen-num, $.content ]
    }

    #| create ast for an indirect reference to this object
    method ind-ref returns Pair {
        :ind-ref[ $.obj-num, $.gen-num ]
    }

}
