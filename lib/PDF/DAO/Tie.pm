use v6;

role PDF::DAO::Tie {

    use PDF::DAO;
    has Attribute $.of-att is rw;      #| default attribute
    has Attribute %.entries;

    my subset IndRef of Pair where {.key eq 'ind-ref'};

    #| generate an indirect reference to ourselves
    method ind-ref returns IndRef {
	my \obj-num = $.obj-num;
	obj-num && obj-num > 0
	    ?? :ind-ref[ obj-num, $.gen-num ]
	    !! die "not an indirect object";
    }

    #| generate an indirect reference, include the reader, if spanning documents
    method link {
	my \obj-num = $.obj-num;
	obj-num && obj-num > 0
	    ?? :ind-ref[ obj-num, $.gen-num, $.reader ]
	    !! self;
    }

    my class Tied {...}

    my role TiedAtt {
        #| override standard Attribute method for generating accessors
	has Tied $.tied is rw handles <tie> = Tied.new;
        method compose(Mu $package) {
            my $key = self.tied.accessor-name;
            my &accessor = sub (\obj) is rw { obj.rw-accessor( self, :$key ); }
            $package.^add_method( $key, &accessor );
            $package.^add_method( self.tied.alias, &accessor)
                if self.tied.alias;
        }
    }

    my role TiedEntry does TiedAtt {
	has Bool $.entry = True;
    }

    my role TiedIndex does TiedAtt {
	has UInt $.index is rw;
    }

    my class Tied is rw {
        has $.type;
	has Bool $.is-required = False;
	has Bool $.is-indirect = False;
	has Bool $.is-inherited = False;
	has Str $.accessor-name;
        has Str $.alias;
	has Code $.coerce = sub ($lval is rw, Mu $type) { PDF::DAO.coerce($lval, $type) };
        has UInt $.length;

        multi method tie(IndRef $lval is rw) { $lval } # undereferenced - don't know it's type yet
	multi method tie($lval is rw, :$check) {
            if $lval.defined && ! ($lval ~~ $!type) {

                my \reader  = $lval.?reader;

                if ($!type ~~ Positional[Mu] && $lval ~~ List)
                || ($!type ~~ Associative[Mu] && $lval ~~ Hash) {
                    # of-att typed array declaration, e.g.:
                    #     has PDF::Catalog @.Kids is entry(:indirect);
                    # or, typed hash declarations, e.g.:
                    #     has PDF::ExtGState %.ExtGState is entry;
                    my \of-type = $!type.of;
                    my Attribute $att = $lval.of-att;
                    if $att {
                        # already processed elsewhere. check that the type matches
                        die "conflicting types for {$att.name} {$att.type.gist} {of-type.gist}"
                            unless of-type ~~ $att.type;
                    }
                    else {
                        # init
                        $att = Attribute.new( :name('@!' ~ $.accessor-name), :type(of-type), :package<?> );
                        $att does TiedIndex;
                        $att.tied = $.clone;
                        $att.tied.type = of-type;
                        $lval.of-att = $att;

                        my \v = $lval.values;
                        if $check {
                            with $.length {
                                die "array not of length: {$_}"
                                    if +v != $_;
                            }
                        }

                        for v {
                            next if $_ ~~ of-type | IndRef;
                            ($att.tied.coerce)($_, of-type);
                            if $check {
                                die "{.WHAT.^name}.$.accessor-name: {.gist} not of type: {$!type.gist}"
                                unless $_ ~~ of-type;
                            }
                            .reader //= reader if reader && .can('reader');
                        }
                    }
                }
                else {
                    ($.coerce)($lval, $!type);
                    if $check {
                        with $lval {
                            die "{.WHAT.^name}.$.accessor-name: {.gist} not of type: {$!type.gist}"
                                unless $_ ~~ $!type;
                        }
                    }
                    $lval.reader  //= $_ with reader;
                }
            }
            else {
                die "missing required field: $.accessor-name"
                    if $check && !$lval.defined && $.is-required;
                $lval.obj-num //= -1
                    if $.is-indirect && $lval ~~ PDF::DAO;
            }
	    $lval;
	}

	multi method tie($lval is copy) is default {
	    $.tie($lval);
	}

    }

    sub process-args($entry, Attribute $att) {

        my constant %Args = %(
            :inherit<is-inherited>, :required<is-required>, :indirect<is-indirect>,
            :coerce<coerce>, :len<length>, :alias<alias>
        );
        my $tied = $att.tied;

	for $entry.list -> \arg {
            if arg ~~ Pair {
	        my \val = arg.value;
                with %Args{arg.key} {
                    $tied."$_"() = val;
                }
                else {
                    warn "ignoring entry attribute: {arg.key}";
                }
            }
            else {
		warn "ignoring entry trait attribute: {arg.perl}"
                    unless arg ~~ Bool;
            }
	}
    }

    multi trait_mod:<is>(Attribute $att, :$entry!) is export(:DEFAULT) {
	my \type = $att.type;
	$att does TiedEntry;
	$att.tied.accessor-name = $att.name.subst(/^(\$|\@|\%)'!'/, '');
	my \sigil = ~ $0;
	given sigil {
	    when '$' {}
	    when '@' {
		# assert that rakudo has interpreted this as Positional[SomeType]
		die "internal error. expecting Positional role, got {type.gist}"
		    unless type ~~ Positional;
	    }
	    when '%' {
		# assert that rakudo has interpreted this as Associative[SomeType]
		die "internal error. expecting Associative role, got {type.gist}"
		    unless type ~~ Associative;
	    }
	    default {
		warn "ignoring '$_' sigil";
	    }
	}
	$att.tied.type = type;
	process-args($entry, $att);
    }

    multi trait_mod:<is>(Attribute $att, :$index! ) is export(:DEFAULT) {
	my \type = $att.type;
	$att does TiedIndex;
	$att.tied.accessor-name = $att.name.subst(/^(\$|\@|\%)'!'/, '');
	my @args = $index.list;
	die "index trait requires a UInt argument, e.g. 'is index(1)'"
	    unless @args && @args[0] ~~ UInt;
	$att.index = @args.shift;
	$att.tied.type = type;
	process-args(@args, $att);
    }

    method lvalue($_) is rw {
        when PDF::DAO  { $_ }
        when Hash | List | DateTime { $.coerce($_, :$.reader) }
        default        { $_ }
    }

    method mixin($role) {
        self.^mixin($role);
        self.tie-init;
        self;
    }

    #| indirect reference
    multi method deref(IndRef $ind-ref!) {
	my (Int $obj-num, Int $gen-num, $reader) = $ind-ref.value.list;

        with $reader // $.reader {
            .auto-deref
                ?? .ind-obj( $obj-num, $gen-num ).object
                !! $ind-ref;
        }
        else {
            die "indirect reference without associated reader: $obj-num $gen-num R";
        }
    }
    #| already an object
    multi method deref(PDF::DAO $value) { $value }

    #| coerce and save hash entry
    multi method deref($value where Hash | List, :$key!) {
        self.ASSIGN-KEY($key, $value);
    }

    #| coerce and save array entry
    multi method deref($value where Hash | List, :$pos!) {
        self.ASSIGN-POS($pos, $value);
    }

    #| simple native type. no need to coerce
    multi method deref($value) is default { $value }
}

=begin pod

This is a role used by PDF::DAO. It makes the PDF object tree appear as a seamless
structure comprised of nested hashs (PDF dictionarys) and arrays.

PDF::DAO::Tie::Hash and PDF::DAO::Tie::Array encapsulate Hash and Array accces.

- If the object has an associated  `reader` property, indirect references are resolved lazily and transparently
as elements in the structure are dereferenced.
- Hashs and arrays automaticaly coerced to objects on assignment to a parent object. For example:

```
sub prefix:</>($name){ PDF::DAO.coerce(:$name) };
my $catalog = PDF::DAO.coerce({ :Type(/'Catalog') });
$catalog<Outlines> = PDF::DAO.coerce( { :Type(/'Outlines'), :Count(0) } );
```

is equivalent to:

```
sub prefix:</>($name){ PDF::DAO.coerce(:$name) };
my $catalog = PDF::DAO.coerce({ :Type(/'Catalog') });
$catalog<Outlines> = { :Type(/'Outlines'), :Count(0) };
```

PDF::DAO::Tie also provides the `entry` trait (hashes) and `index` (arrays) trait for declaring accessors.

=end pod
