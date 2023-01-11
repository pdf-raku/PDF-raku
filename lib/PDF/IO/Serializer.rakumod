use v6;

class PDF::IO::Serializer {

    use PDF::COS;
    use PDF::COS::Stream;
    use PDF::COS::Util :&to-ast;
    use PDF::COS::Type::ObjStm;

    has UInt $.size is rw = 1;      #| first free object number
    has Array %!objects-idx{Any};   #| unique objects index
    has UInt %!ref-count{Any};
    has Bool $.renumber = True;
    has $.reader;
    has Str $.type = $!reader.?type // 'PDF';

    #| Reference count hashes. Could be derivate class of PDF::COS::Dict or PDF::COS::Stream.

    multi method ref-count(Hash $dict) {
        unless %!ref-count{$dict}++ { # already encountered
            $.ref-count($dict{$_}) for $dict.keys.sort
        }
    }

    #| Reference count arrays. Could be derivate class of PDF::COS::Array
    multi method ref-count(Array $array) {
        unless %!ref-count{$array}++ { # already encountered
            $.ref-count($array[$_]) for $array.keys
        }
    }

    #| we don't reference count anything else at the moment.
    multi method ref-count($) { }

    my subset DictIndObj of Pair where {.key eq 'ind-obj'
                                        && .value[2] ~~ Pair
                                        && .value[2].key eq 'dict'}

    my subset LazyObj of Pair where {.key eq 'copy'}

    #| remove and return the root object (trailer dictionary)
    method !get-root(@objects) {
        my DictIndObj \root-ind-obj = @objects.shift; # first object is trailer dict
        root-ind-obj.value[2]<dict>;
    }

    #| Discard Linearization aka "Fast Web View"
    method !discard-linearization(@objects) {
        with @objects[0] -> $obj is copy {
            $obj = $!reader.ind-obj($obj.value[0], $obj.value[1], :get-ast)
                if $obj ~~ LazyObj;
            if $obj ~~ DictIndObj {
                my Hash:D $dict := $obj.value[2]<dict>;
                @objects.shift
                    if $dict<Linearized>:exists;
            }
        }
    }

    proto method body(|c --> Array) {*}

    #| rebuild document body from root
    multi method body( PDF::COS $trailer!, Bool:_ :$*compress, UInt :$!size = 1) {
        temp $trailer.obj-num = 0;
        temp $trailer.gen-num = 0;

        %!ref-count = ();
        $.ref-count( $trailer );
        my @objects = gather { $.freeze( $trailer, :indirect); }
        my %dict = self!get-root(@objects);

        %dict<Size> = $.size
            unless $.type eq 'FDF';

        [ { :@objects, :trailer{ :%dict } }, ];
    }

    #| prepare a set of indirect objects for an incremental update. Only return:
    #| - objects that have been fetched and updated, and
    #| - the trailer dictionary (returned as first object)
    multi method body(
        Bool :$updates! where .so,
        :$*compress,
        :$!size = $!reader.size;
        :$prev = $!reader.prev;
    ) {
        # disable auto-deref to keep all analysis and freeze stages lazy. if it hasn't been
        # loaded, it hasn't been updated
        temp $!reader.auto-deref = False;
        # preserve existing object numbers. updated objects need to be overwritten
        # using the same object and generation numbers
        temp $!renumber = False;
        %!ref-count = ();
        my \trailer = $!reader.trailer;

        temp trailer.obj-num = 0;
        temp trailer.gen-num = 0;

        my @updated-objects = $!reader.get-updates.list;
        $.ref-count($_) for @updated-objects;
        my @objects = gather {
            $.freeze($_, :indirect ) for @updated-objects;
        }

        my %dict = self!get-root(@objects);

        %dict<Prev> = $prev;
        %dict<Size> = $!size;

        [ { :@objects, :trailer{ :%dict } }, ]
    }

    #| return objects without renumbering existing objects. requires a PDF reader
    multi method body( Bool:_ :$*compress, Bool :$eager = True ) {
        my @objects = $!reader.get-objects(:$eager);

        my %dict = self!get-root(@objects);
        self!discard-linearization(@objects);

        %dict<Prev>:delete;
        %dict<Size> = $!reader.size
            unless $.type eq 'FDF';

        [ { :@objects, :trailer{ :%dict } }, ]
    }

    #| construct a reverse index that maps unique $objects
    #| to an object-number and generation-number.
    method !index-object( Pair $node!, :$object!) {
        my Int $obj-num = $object.obj-num 
            if ! $!reader || $object.reader === $!reader;
        my Int $gen-num;
        constant TrailerObjNum = 0;

        if $obj-num.defined && (($obj-num > 0 && ! $!renumber) || $obj-num == TrailerObjNum) {
            # keep original object number
            $gen-num = $object.gen-num;
        }
        else {
            # renumber
            $obj-num = $!size++;
            $gen-num = 0;
        }

        take (:ind-obj[ $obj-num, $gen-num, $node]);
        my $ind-ref = [ $obj-num, $gen-num ];
        %!objects-idx{$object} = $ind-ref;
        :$ind-ref;
    }

    method !freeze-dict( Hash \dict) {
        %( dict.keys.sort.map: { $_ => $.freeze( dict{$_} ) } );
    }

    method !freeze-array( Array \array) {
        [ array.keys.map: { $.freeze( array[$_] ) } ];
    }

    #| should this be serialized as an indirect object?
    multi method is-indirect(PDF::COS::Stream) { True }
    multi method is-indirect(Hash $_ where { .<Type>:exists }) { True }
    multi method is-indirect($_) { %!ref-count{$_} > 1 || ? .obj-num }

    #| prepare an object for output.
    #| - if already encountered, return an indirect reference
    #| - produce an AST from the object content
    #| - determine if the object is indirect, if so index it,
    #|   generating or reusing the object-number in the process.
    proto method freeze(|) {*}

    #| handles PDF::COS::Dict, PDF::COS::Stream, (plain) Hash
    multi method freeze( Hash $object!, Bool :$indirect) {

        with %!objects-idx{$object} -> $ind-ref {
            # already an indirect object
            :$ind-ref
        }
        else {
            my $stream;
            if $object.isa(PDF::COS::Stream) {
                with $*compress {
                    $_ ?? $object.compress !! $object.uncompress
                }
                $stream = $object.encoded;
            }

            my Hash $dict;
            my $node;
            my $node-value := do with $stream {
                my $encoded = .Str;
                $node = :stream{
                    :$dict,
                    :$encoded,
                };
                $node.value<dict>;
            }
            else {
                $node = :$dict;
                $node.value;
            }

            # register prior to traversing the object; in case there are cyclical references
            my \rv = $indirect || $.is-indirect( $object )
              ?? self!index-object($node, :$object )
              !! $node;

            $node-value = self!freeze-dict($object);

            rv;
        }
    }

    #| handles PDF::COS::Array, (plain) Array
    multi method freeze( Array $object!, Bool :$indirect ) {

        with %!objects-idx{$object} -> $ind-ref {
            # already an indirect object
            :$ind-ref
        }
        else {
            my Array $array;
            my $node = :$array;
            my $node-value := $node.value;

            # register prior to traversing the object; in case there are cyclical references
            my \rv = $indirect || $.is-indirect( $object )
                ?? self!index-object($node, :$object )
                !! $node;

            $node-value = $object.of ~~ Numeric
                     ?? $object
                     !! self!freeze-array($object);

            rv;
        }
    }

    #| handles other basic types
    multi method freeze($other) { to-ast $other  }

    #| build AST, starting at the trailer.
    method ast(
        PDF::COS $trailer!,
        Numeric :$version=1.3,
        Str     :$!type,     #| e.g. 'PDF', 'FDF;
        Bool    :$compress,
                :$crypt,
        ) {
        $!type //= ($!reader.?type
                    // do given $trailer<Root> {
                           .defined && .<FDF> ?? 'FDF' !! 'PDF'
                       });
        my Array $body = self.body($trailer, :$compress );
        .crypt-ast('body', $body, :mode<encrypt>)
            with $crypt;
        :cos{ :header{ :$!type, :$version }, :$body };
    }
}
