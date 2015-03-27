use v6;

use PDF::Object :to-ast;
use PDF::Object::Array;
use PDF::Object::Dict;
use PDF::Object::Stream;

class PDF::Storage::Serializer {

    has Int $.size is rw = 1;  # first free object number
    has @.ind-objs;
    has %!obj-num-idx;
    has %.ref-count;
    has Bool $.renumber is rw = True;

    #| analyse stage simply reference counts arrays and hashes. Any that occurs
    #| multiple times is automatically promoted to an indirect object.
    multi method analyse( Hash $dict! is rw) {
        return if %!ref-count{$dict.WHICH}++; # already encountered
        $.analyse($dict{$_}) for $dict.keys;
    }

    multi method analyse( Array $array! is rw ) {
        return if %!ref-count{$array.WHICH}++; # already encountered
        $.analyse($array[$_]) for $array.keys;
    }

    #| we don't reference count anything else at the moment. Might consider
    #| making ind-refs for longish duplicated strings.
    multi method analyse( $other! is rw ) is default {
    }

    #| complete reserialization, from the document root downwards
    method serialize-doc( PDF::Object $root-object!) {
        $.analyse( $root-object );
        my $root = $.freeze( $root-object, :indirect );
        my $objects = $.ind-objs;
        $root-object.post-process( $objects );
        return %( :$root, :$objects );
    }

    method serialize-updates( $reader ) {
        # only renumber new objects, starting from the highest input number + 1 (size)
        $.size = $reader.size;
        temp $.renumber = False;
        my $updates = $reader.get-updates;

        for $updates.list -> $object {
            # reference count new objects
            $.analyse( $object );
        }

        for $updates.list -> $object {
            $.freeze( $object, :indirect )
        }

        my $updated-objects = $.ind-objs;
        return $updated-objects;
    }

    method !get-ind-ref( Str :$id!) {
        :ind-ref( %!obj-num-idx{$id} )
            if %!obj-num-idx{$id}:exists;
    }

    method !index-object( Pair $ind-obj! is rw, Str :$id!, :$object) {
        my $obj-num;
        my $gen-num;

        if ! $.renumber && $object.isa(PDF::Object) && $object.obj-num {
            # keep original object number
            $obj-num = $object.obj-num;
            $gen-num = $object.gen-num;
        }
        else {
            $obj-num = $!size++;
            $gen-num = 0;
        }

        my $ind-ref = [ $obj-num, $gen-num ];
        @.ind-objs.push: (:ind-obj[ $obj-num, $gen-num, $ind-obj]);
        %!obj-num-idx{$id} = $ind-ref;
        :$ind-ref;
    }

    method !freeze-dict( Hash $dict is rw) {
        my %frozen;
        %frozen{$_} = $.freeze( $dict{$_} )
            for $dict.keys;
        %frozen;
    }

    method !freeze-array( Array $array is rw) {
        my @frozen;
        @frozen.push( $.freeze( $array[$_] ) )
            for $array.keys;
        @frozen;
    }

    #| should this be serialized as an indirect object?
    method !is-indirect-object($object, :$id! --> Bool) {

        # multiply referenced objects
        return True if %!ref-count{$id} > 1;

        # streams always need to be indirect objects
        return True if $object ~~ PDF::Object::Stream;

        # type objects are indirect, e.g. << /Type /Catalog .... >>
        return True if ($object ~~ Hash) && ($object<Type>:exists);

        # presumably sourced as an indirect object, so output as such.
        return True if ($object ~~ PDF::Object::Dict | PDF::Object::Array)
            && $object.obj-num;

        return False;
    }

    #| handles PDF::Object::Dict, PDF::Object::Stream, (plain) Hash
    multi method freeze( Hash $object! is rw, Bool :$indirect ) {
        my $id = ~$object.WHICH;

        # already an indirect object
        return self!"get-ind-ref"(:$id )
            if %!obj-num-idx{$id}:exists;

        my $is-stream = $object.isa(PDF::Object::Stream);

        my $ind-obj;
        my $slot;

        if $is-stream {
            $ind-obj = :stream{
                :dict(Mu),
                :encoded($object.encoded),
            };
            $slot := $ind-obj.value<dict>;
        }
        else {
            $ind-obj = dict => Mu;
            $slot := $ind-obj.value;
        }

        # register prior to traversing the object. in case there are cyclical references
        my $ret = $indirect || self!"is-indirect-object"( $object, :$id )
            ?? self!"index-object"($ind-obj, :$id, :$object )
            !! $ind-obj;

        $slot = self!"freeze-dict"($object);

        $ret;
    }

    #| handles PDF::Object::Array, (plain) Array
    multi method freeze( Array $object! is rw, Bool :$indirect ) {
        my $id = ~$object.WHICH;

        # already an indirect object
        return self!"get-ind-ref"( :$id )
            if %!obj-num-idx{$id}:exists;

        my $ind-obj = array => Mu;
        my $slot := $ind-obj.value;

        # register prior to traversing the object. in case there are cyclical references
        my $ret = $indirect || self!"is-indirect-object"( $object, :$id )
            ?? self!"index-object"($ind-obj, :$id, :$object )
            !! $ind-obj;

        $slot = self!"freeze-array"($object);

        $ret;
    }

    #| handles other basic types
    multi method freeze($other) {
        to-ast $other;
    }

}
