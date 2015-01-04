use v6;

use PDF::Basic::Filter;
use PDF::Basic::IndObj ;
use PDF::Basic::Util :unbox;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
our class PDF::Basic::IndObj::Dict
    is PDF::Basic::IndObj {

    has Hash $.dict;

    method new-delegate( :$dict, *%params ) {
        $.delegate-class( :$dict ).new( :$dict, |%params );
    }

    method delegate-class( Hash :$dict! ) {

        BEGIN my $Types = set <Catalog>;

        my $type = $dict<Type> && $dict<Type>.value
            // 'Dict';

        unless $type (elem) $Types {
            warn "unimplemented Indirect Dictionary Object: /Type /$type";
            $type = 'Dict';
        }

        # autoload
        require ::("PDF::Basic::IndObj")::($type);
        return ::("PDF::Basic::IndObj")::($type);
    }

    method content {
        my $s = :$.dict;
        return $s;
    }
}
