use v6;

use PDF::Object;
use PDF::Tools::IndObj;

class PDF::Tools::Serializer {

    has Int $.cur-obj-num is rw = 0;
    has @.ind-objs;

    multi method freeze(PDF::Object $object!) {
        @.ind-objs.push: (:ind-obj[ ++ $.cur-obj-num, 0, $.freeze( $object.content )] );
        return (:ind-ref[ $.cur-obj-num, 0]);
    }

    multi method freeze(Pair $boxed!) {
        $.freeze( |%($boxed.kv) )
    }

    multi method freeze(Hash :$dict!) {
        my %dict = %( $dict.pairs.map( -> $kv { $kv.key => $.freeze($kv.value) } ) );
        if $dict<Type> {
            # any dictionary with a /Type field is implicitly an indirect object
            @.ind-objs.push: (:ind-obj[ ++ $.cur-obj-num, 0, :%dict ]);
            return (:ind-ref[ $.cur-obj-num, 0]);
        }
        :%dict
    }

    multi method freeze(Hash :$stream! ) {
        # streams are always indirect objects
        my $dict = $stream<dict>;
        my %stream = %$stream, $.freeze( :$dict ).kv;
        @.ind-objs.push: (:ind-obj[ ++ $.cur-obj-num, 0, :%stream ]);
        :ind-ref[ $.cur-obj-num, 0];
    }

    multi method freeze(Array :$array! ) {
        # hmm, arrays are always inlined.
        :array[ $array.map({ $.freeze($_) }) ]
    }

    multi method freeze(*%other ) {
        %other;
    }
}
