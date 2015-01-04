use v6;

use PDF::Core::Filter;
use PDF::Core::IndObj ;
use PDF::Core::Util :unbox;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
our class PDF::Core::IndObj::Dict
    is PDF::Core::IndObj {

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
        require ::("PDF::Core::IndObj")::($type);
        return ::("PDF::Core::IndObj")::($type);
    }

    method content {
        my $s = :$.dict;
        return $s;
    }
}
