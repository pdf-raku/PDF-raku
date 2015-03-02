use v6;

use PDF::Object;

class PDF::Tools::Serializer {

    has Int $.next-obj-num is rw = 0;
    has Hash %.serialized-obj-idx;
    has @.ind-objs;

    #= freeze a PDF::Object nested structure to an array of type PDF::Tools::IndObj
    multi method freeze(PDF::Object $object) {
        my $content = $.freeze( $object.content );
        @.ind-objs.push: (:ind-obj[ ++ $.next-obj-num, 0, $content] );
        return (:ind-ref[ $.next-obj-num, 0]);
    }

    multi method freeze(Hash $dict! ) {
        %(
             $dict.pairs.sort.map( -> $kv { $kv.key => $.freeze( $kv.value ) }),
        ).item;
    }

    multi method freeze(Array $array! ) {
        [ $array.map({ $.freeze( $_ ) }) ]
    }

    multi method freeze(Pair $pair) {
        $pair.key =>  $.freeze( $pair.value );
    }

    multi method freeze($value) is default {
        $value;
    }

}
