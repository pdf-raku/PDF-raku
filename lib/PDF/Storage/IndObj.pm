use v6;

class PDF::Storage::IndObj {

    use PDF::DAO;

    has $.object handles <content obj-num gen-num>;

    #| construct by wrapping a pre-existing PDF::DAO
    multi submethod BUILD( PDF::DAO :$!object!, :$obj-num, :$gen-num ) {
	$!object.obj-num = $obj-num if $obj-num.defined;
	$!object.gen-num = $gen-num if $gen-num.defined;
    }

    #| construct an object instance from a PDF::Grammar::PDF ast representation of
    #| an indirect object: [ $obj-num, $gen-num, $type => $content ]
    multi submethod BUILD( Array :$ind-obj!, |c ) {
        my %ast = $ind-obj[2];

        $!object = PDF::DAO.coerce( |%ast, |c );
        $!object.obj-num = $ind-obj[0];
        $!object.gen-num = $ind-obj[1];
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
