use v6;

use PDF::Object :box;
use PDF::Object::Dict;
use PDF::Object::Stream;
use PDF::Tools::IndObj;

class PDF::Tools::Serializer {

    has Int $.cur-obj-num is rw = 0;
    has @.ind-objs;

    method !make-ind-ref($ind-obj) {
        @.ind-objs.push: (:ind-obj[ ++ $.cur-obj-num, 0, $ind-obj]);
        :ind-ref[ $.cur-obj-num, 0];
    }

    method !freeze-dict(Hash $dict) {
        %( $dict.pairs.map( -> $kv { $kv.key => $.freeze( $kv.value ) } ) );
    }

    #| handles PDF::Object::Dict, PDF::Object::Stream, (plain) Hash
    multi method freeze( Hash $object! ) {
        my $has-type = $object<Type>:exists;
        my $frozen = :dict( self!"freeze-dict"($object) );
        my $is-stream = $object.isa(PDF::Object::Stream);
        $frozen = :stream( %( $frozen.kv, :encoded($object.encoded) ) )
            if $is-stream;

        $is-stream || $has-type
            ?? self!"make-ind-ref"($frozen)
            !! $frozen;
    }

    #| handles PDF::Object::Array, (plain( Array
    multi method freeze(Array $array! ) {
        :array[ $array.map({ $.freeze( $_ ) }) ]
    }

    #| fallback for basic types
    multi method freeze($other) {
        box $other;
    }

}
