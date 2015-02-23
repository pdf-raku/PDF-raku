use v6;

use PDF::Tools::Filter;
use PDF::Tools::IndObj ;
use PDF::Tools::Util :unbox;

#| Stream - base class for specific stream objects, e.g. Type::ObjStm, Type::XRef, ...
our class PDF::Tools::IndObj::Stream
    is PDF::Tools::IndObj {

    has Hash $.dict;
    has $!encoded;
    has $!decoded;

    method Filter is rw { %.dict<Filter> }
    method DecodeParms is rw { %.dict<DecodeParms> }
    method Length is rw { %.dict<Length> }

    multi submethod BUILD( :$!dict! is copy, :$start!, :$end!, :$input!) {
        my $length = $end - $start + 1;
        $!encoded = $input.substr($start, $length );
        $!dict<Length> = :int($length);
    }

    multi submethod BUILD( :$!dict is copy = {}, :$!decoded!) {
    }

    multi submethod BUILD( :$!dict! is copy, :$!encoded!) {
        $!dict<Length> = :int($!encoded.chars);
    }

    method new-delegate( :$stream, *%params ) {
        for <start end encoded decoded> {
            %params{$_} = $stream{$_}
            if $stream{$_}:exists;
        }
        my $dict = $stream<dict>;
        $.delegate-class( :$dict ).new( :$dict, |%params );
    }

    method delegate-class( Hash :$dict! ) {

        BEGIN my $Types = set <ObjStm XRef>;

        my $type = $dict<Type> && $dict<Type>.value
            // 'Stream';

        my $subclass;

        if $type (elem) $Types {
            $subclass = 'Type::' ~ $type;
        }
        else {
            warn "unimplemented Indirect Stream Object: /Type /$type"
                unless $type eq 'Stream';
            $subclass = 'Stream';
        }

        # autoload
        require ::("PDF::Tools::IndObj")::($subclass);
        return ::("PDF::Tools::IndObj")::($subclass);
    }

    method encoded {
        if $!decoded.defined && ! $!encoded.defined {
            $!encoded = $.encode( $!decoded );
            $!dict<Length> = :int($!encoded.chars);
        }
        $!encoded;
    }

    method decoded {
        $!decoded //= $.decode( $!encoded )
            if $!encoded.defined;

        $!decoded;
    }

    method decode( Str $encoded = $.encoded ) {
        my $dict = unbox( :$.dict, :keys<Filter DecodeParms> );
        return $encoded unless $dict<Filter>:exists;
        PDF::Tools::Filter.decode( $encoded, :$dict );
    }

    method encode( Str $decoded = $.decoded) {
        my $dict = unbox( :$.dict, :keys<Filter DecodeParms> );
        return $decoded unless $dict<Filter>:exists;
        PDF::Tools::Filter.encode( $decoded, :$dict );
    }

    method content {
        :stream{ :$.dict, :$.encoded };
    }
}
