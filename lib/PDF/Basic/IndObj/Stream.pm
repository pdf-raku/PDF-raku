use v6;

use PDF::Basic::Filter;
use PDF::Basic::IndObj ;
use PDF::Basic::Util :unbox;

#| Stream - base class for specific indirect objects, e.g. ObjStm, XRef, ...
our class PDF::Basic::IndObj::Stream
    is PDF::Basic::IndObj {

    has $.dict;
    has $.encoded;
    has $.decoded;

    method indobj-new( :$stream, *%params ) {
        for <dict start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my $dict = $stream<dict>;
        $.indobj-class( :$dict ).new( |%params );
    }

    method indobj-class( Hash :$dict! ) {

        BEGIN my $Types = set <Stream Catalog ObjStm XRef>;

        my $type = $dict<Type> && $dict<Type>.value
            // 'Stream';

        unless $type (elem) $Types {
            warn "unimplemented Indirect Stream Object: /Type /$type";
            $type = 'Stream';
        }

        # autoload
        require ::("PDF::Basic::IndObj")::($type);
        return ::("PDF::Basic::IndObj")::($type);
    }

    multi submethod BUILD( :$!dict!, :$start!, :$end!, :$input!) {
        my $length = $end - $start + 1;
        $!encoded = $input.substr($start - 1, $length - 1 );
    }

    multi submethod BUILD( :$!dict!, :$!decoded, :$!encoded) {
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

    method Filter is rw {
        %.dict<Filter>;
    }

    method DecodeParms is rw {
        %.dict<DecodeParms>;
    }

    method Type is rw {
        %.dict<Type>;
    }

    method decode( $encoded = $.encoded ) {
        my $dict = unbox( :$.dict, :keys<Filter DecodeParms> );
        PDF::Basic::Filter.decode( $encoded, :$dict );
    }

    method encode( $decoded = $.decoded) {
        my $dict = unbox( :$.dict, :keys<Filter DecodeParms> );
        PDF::Basic::Filter.encode( $decoded, :$dict );
    }

    method content {
        my $s = :stream{ :$.dict, :$.encoded };
        return $s;
    }
}
