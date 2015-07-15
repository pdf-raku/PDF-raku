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

    #| Reference count hashes. Could be derivate class of PDF::Object::Dict or PDF::Object::Stream.
    multi method analyse( Hash $dict! is rw) {
        return if %!ref-count{$dict.WHICH}++; # already encountered
        $.analyse($dict{$_}) for $dict.keys;
    }

    #| Reference count arrays. Could be derivate class of PDF::Object::Array
    multi method analyse( Array $array! is rw ) {
        return if %!ref-count{$array.WHICH}++; # already encountered
        $.analyse($array[$_]) for $array.keys;
    }

    #| we don't reference count anything else at the moment.
    multi method analyse( $other! is rw ) is default {
    }

    #| rebuilds the body
    multi method body( PDF::Object $root-object!, Hash :$trailer-dict = {}, :$*compress) {
        $root-object.?cb-finish;
        %!ref-count = ();
        $.analyse( $root-object );
        my $root = $.freeze( $root-object, :indirect);
        my $objects = $.ind-objs;

        my %dict = $trailer-dict.list;
        %dict<Prev>:delete;
        %dict<Root> = $root;
        %dict<Size> = :int($.size);

        return %( :$objects, :trailer{ :%dict } );
    }

    #| prepare a set of objects for an incremental update. Only return indirect objects:
    #| - that have been fetched and updated, or
    #| - have been newly inserted (no object-number)
    #| of course, 
    multi method body( $reader, Bool :$updates! where $_, Hash :$trailer-dict = {}, :$*compress ) {
        # only renumber new objects, starting from the highest input number + 1 (size)
        my $root-object = $reader.root.object;
        $root-object.?cb-finish;

        $.size = $reader.size;
        my $prev = $reader.prev;
        my $root-ref = $reader.root.ind-ref;

        # disable auto-deref to keep all analysis and freeze stages lazy. We don't
        # need to consider or load anything that has not been already.
        temp $reader.auto-deref = False;

        # preserve existing object numbers. objects need to overwritten using the same
        # object and generation numbers
        temp $.renumber = False;
        %!ref-count = ();

        my $updated-objects = $reader.get-updates;

        for $updated-objects.list -> $object {
            # reference count new objects
            $.analyse( $object );
        }

        for $updated-objects.list -> $object {
            $.freeze( $object, :indirect )
        }

        my %dict = $trailer-dict.list;
        %dict<Prev> = :int($prev);
        %dict<Root> = $root-ref;
        %dict<Size> = :int($.size);

        my $objects = $.ind-objs;
        return {
            :$objects,
            :trailer{ :%dict },
        }
    }

    method !get-ind-ref( Str :$id!) {
        :ind-ref( %!obj-num-idx{$id} )
            if %!obj-num-idx{$id}:exists;
    }

    #| construct a reverse index that unique maps unique $objects, identfied by .WHICH,
    #| to an object-number and generation-number. 
    method !index-object( Pair $ind-obj! is rw, Str :$id!, :$object) {
        my Int $obj-num;
        my Int $gen-num;

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

    #| prepare and object for output.
    #| - if already encountered, return an indirect reference
    #| - produce an AST from the object content
    #| - determine if the object is indirect, if so index it,
    #|   generating or reusing the object-number in the process.
    proto method freeze(|) {*}

    #| handles PDF::Object::Dict, PDF::Object::Stream, (plain) Hash
    multi method freeze( Hash $object! is rw, Bool :$indirect) {
        my $id = ~$object.WHICH;

        # already an indirect object
        return self!"get-ind-ref"(:$id )
            if %!obj-num-idx{$id}:exists;

        my Bool $is-stream = $object.isa(PDF::Object::Stream);

        if $is-stream && $*compress.defined {
            $*compress ?? $object.compress !! $object.uncompress;
        }

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
