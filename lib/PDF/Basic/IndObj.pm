use v6;

class PDF::Basic::IndObj;

use PDF::Basic::IndObj::Catalog;
use PDF::Basic::IndObj::ObjStm;
use PDF::Basic::IndObj::Stream;
use PDF::Basic::IndObj::XRef;

method indobj-new( Hash :$dict ) {
    $.indobj-class( :$dict ).new( :$dict );
}

method indobj-class( Hash :$dict! ) {

    BEGIN our %Classes =
        Catalog => PDF::Basic::IndObj::Catalog,
        ObjStm => PDF::Basic::IndObj::ObjStm,
        XRef => PDF::Basic::IndObj::XRef,
        ;

    my $type = $dict<Type>
        // die "mandatory /Type entry missing from Indirect Object dictionary";

    my $class = %Classes{ $type }:exists
        ?? %Classes{ $type }
        !! do {
            warn "unimplemented Indirect Object type: $type";
            PDF::Basic::IndObj::Stream;
        };

    return $class;
}
