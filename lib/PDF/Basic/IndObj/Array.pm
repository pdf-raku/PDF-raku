use v6;

use PDF::Basic::Writer;
use PDF::Basic::IndObj ;

#| Stream - base class for specific indirect objects, e.g. ObjStm, XRef, ...
our class PDF::Basic::IndObj::Array
    is PDF::Basic::IndObj {

    has Array $.decoded;
    has Str $.encoded;

    multi submethod BUILD(:$array!) {
        $!decoded = $array;
    }

    multi submethod BUILD( :$!decoded, :$!encoded) {
    }

    method indobj-new( *%params ) {
        $.new( |%params );
    }

    method encoded {
        $!encoded //= $.encode( $!decoded )
            if $!decoded.defined;
        $!encoded;
    }

    method decoded {
        $!decoded //= $.decode( $!encoded )
            if $!encoded.defined;
        $!decoded;
    }

    method decode( $encoded = $.encoded; ) {
        use PDF::Grammar::PDF;
        use PDF::Grammar::PDF::Actions;
        my $actions = PDF::Grammar::PDF::Actions.new;

        my $input = $.encoded;
        PDF::Grammar::PDF.parse($encoded, :$actions, :rule<array>)
            // die "unable to parse bnd-obj: $input";
    }

    method encode( $array = $.decoded ) {
        PDF::Basic::Writer.write( :$array );
    }
}
