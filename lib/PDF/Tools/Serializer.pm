use v6;

use PDF::Object :to-ast;
use PDF::Object::Dict;
use PDF::Object::Stream;
use PDF::Tools::IndObj;

class PDF::Tools::Serializer {

    has Int $!cur-obj-num = 0;
    has @.ind-objs;
    has %!obj-num;

    method !make-ind-ref( Pair $ind-obj, Int :$id!) {
        if %!obj-num{$id}:exists {
            :ind-ref[ %!obj-num{$id}, 0 ]
        }
        else {
            my $obj-num = ++ $!cur-obj-num;
            @.ind-objs.push: (:ind-obj[ $obj-num, 0, $ind-obj]);
            %!obj-num{$id} = $obj-num;
            :ind-ref[ $obj-num, 0];
        }
    }

    method !freeze-dict( Hash $dict) {
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
            ?? self!"make-ind-ref"($frozen, :id($object.WHERE) )
            !! $frozen;
    }

    #| handles PDF::Object::Array, (plain( Array
    multi method freeze( Array $array! ) {
        :array[ $array.map({ $.freeze( $_ ) }) ]
    }

    #| handles other basic types
    multi method freeze($other) {
        to-ast $other;
    }

}
