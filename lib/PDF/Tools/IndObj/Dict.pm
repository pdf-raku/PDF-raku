use v6;

use PDF::Tools::Filter;
use PDF::Tools::IndObj ;
use PDF::Tools::Util :unbox;

#| Dict - base class for dictionary objects, e.g. Catalog Page ...
our class PDF::Tools::IndObj::Dict
    is PDF::Tools::IndObj {

    has Hash $.dict;

    method new-delegate( :$dict, *%params ) {
        $.delegate-class( :$dict ).new( :$dict, |%params );
    }

    method delegate-class( Hash :$dict! ) {

        BEGIN my $Types = set <Catalog>;

        my $type = $dict<Type> && $dict<Type>.value
            // 'Dict';

        my $subclass;

        if $type (elem) $Types {
            $subclass = 'Type::' ~ $type;
        }
        else {
            warn "unimplemented Indirect Dictionary Object: /Type /$type"
                unless $type eq 'Dict';
            $subclass = 'Dict';
        }

        # autoload
        require ::("PDF::Tools::IndObj")::($subclass);
        return ::("PDF::Tools::IndObj")::($subclass);
    }

    method content {
        my $s = :$.dict;
        return $s;
    }
}
