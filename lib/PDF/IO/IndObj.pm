use v6;

class PDF::IO::IndObj {

    use PDF::DAO;
    has $.object handles <content obj-num gen-num>;

    #| construct by wrapping a pre-existing PDF::DAO
    multi submethod BUILD( PDF::DAO :$!object!, :$obj-num, :$gen-num ) {
	$!object.obj-num = $_ with $obj-num;
	$!object.gen-num = $_ with $gen-num;
    }

    #| construct an object instance from a PDF::Grammar::PDF ast representation of
    #| an indirect object: [ $obj-num, $gen-num, $type => $content ]
    multi submethod BUILD( Array :$ind-obj!, |c ) {
        $!object = PDF::DAO.coerce( |$ind-obj[2], |c );
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
