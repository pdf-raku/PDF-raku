use v6;

role PDF::COS::Tie {

    use PDF::COS :IndRef;
    has Attribute $.of-att is rw;      #| default attribute
    has Attribute %.entries;
    my constant $Lock = Lock.new;

    #| generate an indirect reference to ourselves
    method ind-ref returns IndRef {
	given $.obj-num {
            $_ && $_ > 0
                ?? :ind-ref[ $_, $.gen-num ]
                !! die "not an indirect object";
        }
    }

    #| generate an indirect reference, include the reader, if spanning documents
    method link {
	given $.obj-num {
	    .defined && $_ > 0
	        ?? :ind-ref[ $_, $.gen-num, $.reader ]
	        !! self;
        }
    }

    my class COSAttr {...}

    my role COSAttrHOW {
        #| override standard Attribute method for generating accessors
	has COSAttr $.cos is rw handles<tie raku>;
        method tied is rw is DEPRECATED("Please use .cos()") { $.cos }

        method compose(Mu $package) {
            my $key = self.cos.accessor-name;
            my &accessor = sub (\obj) is rw { obj.rw-accessor( self, :$key ); }
            &accessor.set_name( $key );
            try $package.^add_method($key, &accessor);
            if self.cos.alias {
                try $package.^add_method(self.cos.alias, &accessor);
            }
        }
    }

    my role COSDictAttrHOW does COSAttrHOW is export(:COSDictAttrHOW) {
	has Bool $.entry = True;
    }

    my role COSArrayAttrHOW does COSAttrHOW is export(:COSArrayAttrHOW) {
	has UInt $.index is rw;
    }

    my class COSAttr {
        has $.type;
	has Bool $.is-required = False;
	has Bool $.is-indirect = False;
	has Bool $.is-inherited = False;
        has Bool $.decont = False;
	has Str  $.accessor-name;
        has Str  $.alias;
	has Code $.coerce = sub ($lval is rw, Mu $type) { PDF::COS.coerce($lval, $type) };
        has UInt $.length;
        has $.default;
        my class CosOfAttr is Attribute does COSAttrHOW {}
        has CosOfAttr $!of-att;

        method of-att {
            # anonymous attribute for individual items in an array or hash
            unless $!of-att.defined {
                $Lock.protect: {
                    without $!of-att {
                        my $type := $!type.of;
                        $_ = CosOfAttr.new( :name('@!' ~ $.accessor-name), :$type, :package<?> );
                        .cos = $.clone(:!decont, :$type);
                    }
                }
            }
            $!of-att;
        }

        multi method tie(IndRef $lval is rw) is rw { $lval } # undereferenced - don't know it's type yet
        multi method tie($lval is rw where !.defined, :$check) is rw {
            if $check {
                return $.tie( PDF::COS.coerce($_)) with $.default;
                die "missing required field: $.accessor-name"
                    if $.is-required;
            }
            $lval;
        }
        method !tie-container($lval is raw, :$check) {
            # of-att typed array declaration, e.g.:
            #     has PDF::Catalog @.Kids is entry(:indirect);
            # or, typed hash declarations, e.g.:
            #     has PDF::ExtGState %.ExtGState is entry;
            my \reader  = $lval.?reader;
            my Attribute $att := $lval.of-att;
            if $att.defined {
                # already processed elsewhere. check that the type matches
                die "conflicting types for {$att.name} {$att.type.gist} {$!type.of.gist}"
                    unless $!type.of ~~ $att.type;
            }
            else {
                $att = self.of-att;
                my \of-type = $att.type;
                my \v = $lval.values;

                if $check {
                    with $.length {
                        die "array not of length: {$_}"
                            if +v != $_;
                    }
                }

                for v {
                    unless $_ ~~ of-type | IndRef {
                        ($att.cos.coerce)($_, of-type);
                        if $check {
                            die "{.WHAT.^name}.$.accessor-name: {.gist} not of type: {of-type.^name}"
                            unless $_ ~~ of-type;
                        }
                        .reader //= reader if .defined;
                    }
                }
            }
        }
        multi method tie($lval is rw where !($lval ~~ $!type), :$check) is rw {
            $Lock.protect: {

                if ($!type ~~ Positional[Mu] && $lval ~~ List)
                || ($!type ~~ Associative[Mu] && $lval ~~ Hash) {
                    self!tie-container: $lval, :$check;
                }
                elsif $lval.isa(array) && $!type ~~ Positional[Numeric] {
                    # assume numeric. not so easy to type-check atm
                    # https://github.com/rakudo/rakudo/issues/4485
                    # update: fixed as of Rakudo 2021.08
                }
                else {
                    my \of-type = $!decont ?? $!type.of !! $!type;
                    unless $lval ~~ of-type {
                        ($.coerce)($lval, of-type);
                        if $check {
                            with $lval {
                                die "{.WHAT.^name}.$.accessor-name: {.gist} not of type: {$!type.^name}"
                                    unless $_ ~~ of-type;
                            }
                        }
                    }
                }
            }
            $lval;
        }
	multi method tie($lval is rw, :$check) is rw {
            $Lock.protect: {
                $lval.obj-num //= -1
            } if $.is-indirect && $lval ~~ PDF::COS;

	    $lval;
	}

	multi method tie($lval is copy, :$check) is rw {
	    $.tie($lval, :$check);
	}

        method raku {
            my $sigil;
            my $type;
            given $!type {
                when Positional[Mu]  { $type := $!type.of; $sigil := '@' }
                when Associative[Mu] { $type := $!type.of; $sigil := '%' }
                default              { $type := $!type;    $sigil := '$' }
            }
            my $alias = do with $!alias { ' (' ~ $_ ~ ')' } // '';
            [~] ($type.raku, ' ', $sigil, '.', $!accessor-name, $alias);
        }
    }

    sub cos-attr-opts($entry, Attribute $att) {

        my constant %Args = %(
            :inherit<is-inherited>, :required<is-required>, :indirect<is-indirect>,
            :coerce<coerce>, :len<length>, :alias<alias>, :array-or-item<decont>,
            :key<key>, :default<default>
        );

        my %opts = type => $att.type, accessor-name => $att.name.subst(/^(\$|\@|\%)'!'/, '');

        for $entry.list -> \arg {
            if arg ~~ Pair {
                my \val = arg.value;
                with %Args{arg.key} {
                    %opts{$_} = val;
                }
                else {
                    warn "ignoring entry attribute: {arg.key}";
                }
            }
            else {
                warn "ignoring entry trait attribute: {arg.raku}"
                unless arg ~~ Bool;
            }
        }
        with %opts<key>:delete {
            # swap method name and alias
            %opts<alias> = %opts<accessor-name>;
            %opts<accessor-name> = $_;
        }
        warn ':item-or-array should be used with arrays ("@" sigil)'
            if %opts<decont> && $att.type !~~ Positional[Mu];
        %opts;
    }

    multi trait_mod:<is>(Attribute $att, :$entry!) is export(:DEFAULT) {
	$att does COSDictAttrHOW;
        $att.cos .= new: |cos-attr-opts($entry, $att);
    }

    multi trait_mod:<is>(Attribute $att, :$index! ) is export(:DEFAULT) {
	my @args = $index.list;
	die "index trait requires a UInt argument, e.g. 'is index(1)'"
	    unless @args && @args[0] ~~ UInt;
	$att does COSArrayAttrHOW;
	$att.index = @args.shift;
	$att.cos .= new: |cos-attr-opts(@args, $att);
    }

    method lvalue($_) is rw {
        when PDF::COS  { $_ }
        when Hash | List | DateTime { $.coerce($_, :$.reader) }
        default        { $_ }
    }

    method mixin(Any:D: $role is raw) {
        unless $.does($role) {
            $.^mixin($role);
            $.tie-init;
        }
        self;
    }

    # apply ourselves, if we're a punned role
    method induce($obj is raw) {
        $obj.mixin: self.^pun_source
            if self.^is_pun;
        $obj;
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
    multi method deref(PDF::COS $value) { $value }

    #| coerce and save hash entry
    multi method deref($value where Hash | List, :$key!) {
        self.ASSIGN-KEY($key, $value);
    }

    #| coerce and save array entry
    multi method deref($value where Hash | List, :$pos!) {
        self.ASSIGN-POS($pos, $value);
    }

    #| simple value. no need to coerce
    multi method deref($value) { $value }
}

=begin pod

This is a role used by PDF::COS. It makes the PDF object tree appear as a seamless
structure comprised of nested hashs (PDF dictionarys) and arrays.

PDF::COS::Tie::Hash and PDF::COS::Tie::Array encapsulate Hash and Array access.

- If the object has an associated  `reader` property, indirect references are resolved lazily and transparently
as elements in the structure are dereferenced.
- Hashs and arrays automaticaly coerced to objects on assignment to a parent object. For example:

```
sub prefix:</>($name){ PDF::COS.coerce(:$name) };
my $catalog = PDF::COS.coerce({ :Type(/'Catalog') });
$catalog<Outlines> = PDF::COS.coerce( { :Type(/'Outlines'), :Count(0) } );
```

is equivalent to:

```
sub prefix:</>($name){ PDF::COS.coerce(:$name) };
my $catalog = PDF::COS.coerce({ :Type(/'Catalog') });
$catalog<Outlines> = { :Type(/'Outlines'), :Count(0) };
```

PDF::COS::Tie also provides the `entry` trait (hashes) and `index` (arrays) trait for declaring accessors.

=end pod
