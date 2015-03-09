use v6;

use PDF::Object;
use PDF::Object::Dict;
use PDF::Tools::IndObj;

class PDF::Tools::Serializer {

    has Int $.cur-obj-num is rw = 0;
    has @.ind-objs;

    method !make-ind-ref($ind-obj) {
        @.ind-objs.push: (:ind-obj[ ++ $.cur-obj-num, 0, $ind-obj]);
        :ind-ref[ $.cur-obj-num, 0];
    }

    method !freeze-dict(Hash $dict) {
        %( $dict.pairs.map( -> $kv { $kv.key => $.freeze( |%( $kv.value) ) } ) );
    }

    method freeze-doc( PDF::Object::Dict $object ) {
        die "root dictionary lacks a /Type entry"
            unless $object<Type>;
        $.freeze($object);
    }

    multi method freeze(PDF::Object $object!) {
        $.freeze( |%($object.content) );
    }

    multi method freeze(Hash :$dict!) {
        my %dict = self!"freeze-dict"($dict);
        # any dictionary with a /Type field is implicitly an indirect object
        $dict<Type>
            ?? self!"make-ind-ref"((:%dict))
            !! :%dict;
    }

    multi method freeze(Hash :$stream!) {
        # streams are always indirect objects
        my %stream = %( $stream );
        %stream<dict> = self!"freeze-dict"( $stream<dict> );
        self!"make-ind-ref"((:%stream))
    }

    multi method freeze(Array :$array! ) {
        :array[ $array.map({ $.freeze( |%$_ ) }) ]
    }

    #| Simple type. :name, :num, ...
    multi method freeze(*%misc ) {
        die "unhandled struct: {%misc.perl}"
            if +%misc != 1;
        %misc[0];
    }
}
