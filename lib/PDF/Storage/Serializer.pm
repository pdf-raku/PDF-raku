use v6;

class PDF::Storage::Serializer {

    use PDF::DAO;
    use PDF::DAO::Array;
    use PDF::DAO::Dict;
    use PDF::DAO::Stream;
    use PDF::DAO::Util :to-ast;
    use PDF::Writer;

    has UInt $.size is rw = 1;  #| first free object number
    has Pair  @!objects;        #| renumbered objects
    has Array %!objects-idx;    #| @objects index, by id
    has UInt %.ref-count;
    has Bool $.renumber is rw = True;
    has Str $!type;             #| 'FDF', 'PDF', .. others?
    has $.reader;

    method type { $!type //= $.reader.?type // 'PDF' }

    #| Reference count hashes. Could be derivate class of PDF::DAO::Dict or PDF::DAO::Stream.
    multi method analyse( Hash $dict!) {
        return if %!ref-count{$dict.WHICH}++; # already encountered
        $.analyse($dict{$_}) for $dict.keys.sort;
    }

    #| Reference count arrays. Could be derivate class of PDF::DAO::Array
    multi method analyse( Array $array!) {
        return if %!ref-count{$array.WHICH}++; # already encountered
        $.analyse($array[$_]) for $array.keys;
    }

    #| we don't reference count anything else at the moment.
    multi method analyse( $other! ) is default {
    }

    method !get-root(@objects) {
	my subset DictIndObj of Pair where {.key eq 'ind-obj'
					       && .value[2] ~~ Pair
					       && .value[2].key eq 'dict'}
	my DictIndObj $root-ind-obj = @objects.shift; # first object is trailer dict
	$root-ind-obj.value[2]<dict>;
    }

    proto method body(|c --> Array) {*}

    #| rebuild document body from root
    multi method body( PDF::DAO $trailer!, Bool:_ :$*compress, UInt :$!size = 1) {

	temp $trailer.obj-num = 0;
	temp $trailer.gen-num = 0;

        %!ref-count = ();
	@!objects = ();
        $.analyse( $trailer );
        $.freeze( $trailer, :indirect);
	my %dict = self!get-root(@!objects);

        %dict<Size> = :int($.size)
	    unless $.type eq 'FDF';

        [ { :@!objects, :trailer{ :%dict } }, ];
    }

    #| prepare a set of objects for an incremental update. Only return indirect objects:
    #| - objects that have been fetched and updated, and
    #| - the trailer dictionary (returned as first object)
    multi method body( Bool :$updates! where $updates, :$*compress ) {
        # only renumber new objects, starting from the highest input number + 1 (size)
        $.size = $.reader.size;
        my $prev = $.reader.prev;

        # disable auto-deref to keep all analysis and freeze stages lazy. if it hasn't been
        # loaded, it hasn't been updated
        temp $.reader.auto-deref = False;

        # preserve existing object numbers. objects need to overwritten using the same
        # object and generation numbers
        temp $.renumber = False;
        %!ref-count = ();
	@!objects = ();
	my $trailer = $.reader.trailer;

	temp $trailer.obj-num = 0;
	temp $trailer.gen-num = 0;

        my @updated-objects = $.reader.get-updates.list;

        for @updated-objects -> $object {
            # reference count new objects
            $.analyse( $object );
        }

	for @updated-objects -> $object {
	    $.freeze( $object, :indirect )
	}

	my %dict = self!get-root(@!objects);

        %dict<Prev> = :int($prev);
        %dict<Size> = :int($.size);

        [ { :@!objects, :trailer{ :%dict } }, ]
    }

    #| return objects without renumbering existing objects. requires a PDF reader
    multi method body( Bool:_ :$*compress ) is default {
        my @objects = @( $.reader.get-objects );
	my %dict = self!get-root(@objects);
        %dict<Prev>:delete;
        %dict<Size> = :int($.reader.size)
            unless $.type eq 'FDF';

        [ { :@objects, :trailer{ :%dict } }, ]
    }

    method !get-ind-ref( Str :$id!) {
        :ind-ref( %!objects-idx{$id} )
            if %!objects-idx{$id}:exists;
    }

    #| construct a reverse index that unique maps unique $objects, identified by .WHICH,
    #| to an object-number and generation-number. 
    method !index-object( Pair $ind-obj! is rw, Str :$id!, :$object) {
        my Int $obj-num = $object.obj-num 
	    if $object.can('obj-num')
	    && (! $.reader || $object.reader === $.reader);
        my UInt $gen-num;
	my subset IsTrailer of UInt where 0;

        if $obj-num.defined && (($obj-num > 0 && ! $.renumber) || $obj-num ~~ IsTrailer) {
            # keep original object number
            $gen-num = $object.gen-num;
        }
        else {
            # renumber
            $obj-num = $!size++;
            $gen-num = 0;
        }

        @!objects.push: (:ind-obj[ $obj-num, $gen-num, $ind-obj]);
        my $ind-ref = [ $obj-num, $gen-num ];
        %!objects-idx{$id} = $ind-ref;
        :$ind-ref;
    }

    method !freeze-dict( Hash $dict) {
        my %frozen;
        %frozen{$_} = $.freeze( $dict{$_} )
            for $dict.keys.sort;
        %frozen;
    }

    method !freeze-array( Array $array) {
        my @frozen;
        @frozen.push( $.freeze( $array[$_] ) )
            for $array.keys;
        @frozen;
    }

    #| should this be serialized as an indirect object?
    multi method is-indirect($ --> Bool) {*}

    #| streams always need to be indirect objects
    multi method is-indirect(PDF::DAO::Stream $object)                    {True}

    #| avoid duplication of multiply referenced objects
    multi method is-indirect($, :$id! where {%!ref-count{$id} > 1})       {True}

    #| typed objects should be indirect, e.g. << /Type /Catalog .... >>
    multi method is-indirect(Hash $obj where {.<Type>:exists})            {True}

    #| presumably sourced as an indirect object, so output as such.
    multi method is-indirect($obj where { .can('obj-num') && .obj-num })  {True}

    #| allow anything else to inline
    multi method is-indirect($) is default                                {False}

    #| prepare an object for output.
    #| - if already encountered, return an indirect reference
    #| - produce an AST from the object content
    #| - determine if the object is indirect, if so index it,
    #|   generating or reusing the object-number in the process.
    proto method freeze(|) {*}

    #| handles PDF::DAO::Dict, PDF::DAO::Stream, (plain) Hash
    multi method freeze( Hash $object!, Bool :$indirect) {
        my $id = ~$object.WHICH;

        # already an indirect object
	if %!objects-idx{$id}:exists {
	    my $ind-ref = self!get-ind-ref( :$id );
	    return $ind-ref;
	}

        my Bool $is-stream = $object.isa(PDF::DAO::Stream);

        if $is-stream && $*compress.defined {
            $*compress ?? $object.compress !! $object.uncompress;
        }

        my $ind-obj;
        my $slot;
	my $dict;

        if $is-stream {
	    my $encoded = $object.encoded;
            $ind-obj = :stream{
                :$dict,
                :$encoded,
            };
            $slot := $ind-obj.value<dict>;
        }
        else {
            $ind-obj = :$dict;
            $slot := $ind-obj.value;
        }

        # register prior to traversing the object. in case there are cyclical references
        my $ret = $indirect || $.is-indirect( $object, :$id )
            ?? self!index-object($ind-obj, :$id, :$object )
            !! $ind-obj;

        $slot = self!freeze-dict($object);

        $ret;
    }

    #| handles PDF::DAO::Array, (plain) Array
    multi method freeze( Array $object!, Bool :$indirect ) {
        my $id = ~$object.WHICH;

        # already an indirect object
	if %!objects-idx{$id}:exists {
	    my $ind-ref = self!get-ind-ref( :$id );
	    return $ind-ref;
	}

	my $array;

        my $ind-obj = :$array;
        my $slot := $ind-obj.value;

        # register prior to traversing the object. in case there are cyclical references
        my $ret = $indirect || $.is-indirect( $object, :$id )
            ?? self!index-object($ind-obj, :$id, :$object )
            !! $ind-obj;

        $slot = self!freeze-array($object);

        $ret;
    }

    #| handles other basic types
    multi method freeze($other) is default {
	to-ast $other
    }

    #| do a full save to the named file
    multi method save-as(Str $file-name!,
			 PDF::DAO $trailer-dict!,
                         Numeric :$version=1.3,
                         Str     :$!type,     #| e.g. 'PDF', 'FDF;
                         Bool    :$compress,
			 Bool    :$crypt,
        ) {
	$!type //= $.reader.?type;
	$!type //= $file-name ~~ /:i '.fdf' $/  ?? 'FDF' !! 'PDF';
        my Array $body = self.body($trailer-dict, :$compress );
	$crypt.crypt-ast('body', $body)
	    if $crypt;
        my Pair $ast = :pdf{ :header{ :$!type, :$version }, :$body };
        my $writer = PDF::Writer.new( );
        use JSON::Fast;
        $file-name ~~ m:i/'.json' $/
            ?? $file-name.IO.spurt( to-json( $ast ))
            !! $file-name.IO.spurt( $writer.write( $ast ), :enc<latin-1> );
    }
}
