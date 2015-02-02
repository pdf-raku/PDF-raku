use v6;

use PDF::Tools::Filter;
use PDF::Tools::IndObj ;
use PDF::Tools::Util :unbox;

#| Stream - base class for specific stream objects, e.g. ObjStm, XRef, ...
our class PDF::Tools::IndObj::Stream
    is PDF::Tools::IndObj {

    has Hash $.dict;
    has $.encoded;
    has $.decoded;

    method new-delegate( :$stream, *%params ) {
        for <start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my $dict = $stream<dict>;
        $.delegate-class( :$dict ).new( :$dict, |%params );
    }

    method delegate-class( Hash :$dict! ) {

        BEGIN my $Types = set <Stream Catalog ObjStm XRef>;

        my $type = $dict<Type> && $dict<Type>.value
            // 'Stream';

        unless $type (elem) $Types {
            warn "unimplemented Indirect Stream Object: /Type /$type";
            $type = 'Stream';
        }

        # autoload
        require ::("PDF::Tools::IndObj")::($type);
        return ::("PDF::Tools::IndObj")::($type);
    }

    multi submethod BUILD( :$!dict!, :$start!, :$end!, :$input!) {
        my $length = $end - $start + 1;
        $!encoded = $input.substr($start - 1, $length - 1 );
    }

    multi submethod BUILD( :$!dict!, :$!decoded!) {
    }

    multi submethod BUILD( :$!dict!, :$!encoded!) {
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

    method decode( Str $encoded = $.encoded ) {
        my $dict = unbox( :$.dict, :keys<Filter DecodeParms> );
        PDF::Tools::Filter.decode( $encoded, :$dict );
    }

    method encode( Str $decoded = $.decoded) {
        my $dict = unbox( :$.dict, :keys<Filter DecodeParms> );
        PDF::Tools::Filter.encode( $decoded, :$dict );
    }

    method content {
        my $s = :stream{ :$.dict, :$.encoded };
        return $s;
    }
}
