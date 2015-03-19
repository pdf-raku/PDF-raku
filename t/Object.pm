use v6;

use PDF::Object :from-ast;

class t::Object {

    proto sub to-obj(|) is export(:to-obj) {*};

    multi sub to-obj( Pair $p! ) {
        to-obj( |%( $p.kv ) );
    }

    multi sub to-obj( Array :$array! ) {
        [ $array.map: { to-obj( $_ ) } ];
    }

    multi sub to-obj( Hash :$dict!, :$keys ) {
        my @keys = $keys.defined
            ?? $keys.grep: {$dict{$_}:exists}
        !! $dict.keys;
        my %hash = @keys.map: { $_ => to-obj( $dict{$_} ) };
        %hash.item;
    }

    multi sub to-obj( Hash :$stream! ) {
        my $dict = $stream<dict>;
        my %stream = %$stream, dict => to-obj( :$dict );
        %stream;
    }

    multi sub to-obj( Array :$ind-obj! ) {
        my %content = $ind-obj[2].kv;
        to-obj( |%content )
    }

    multi sub to-obj( Array $array) { to-obj( :$array ) }
    multi sub to-obj( Hash $dict) { to-obj( :$dict ) }

    multi sub to-obj( *%opt ) is default {
        from-ast( |%opt);
    }

}
