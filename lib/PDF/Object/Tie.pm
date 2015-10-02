use v6;

use PDF::Object;

role PDF::Object::Tie {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

    method is-indirect is rw returns Bool {
	Proxy.new(
	    FETCH => method { ?$.obj-num },
	    STORE => method (Bool $val) {
		if $val {
		    # Serializer will renumber
		    $.obj-num //= -1;
		}
		else {
		    $.obj-num = Nil;
		}
		$val
	    },
	    );
    }

    method ind-ref {
	die "not an indirect obect"
	    unless $.obj-num && $.obj-num > 0;
	:ind-ref[ $.obj-num, $.gen-num ];
    }

    my role Tied {
	has Bool $.is-required is rw = False;
	has Bool $.is-indirect is rw = False;
	has Bool $.is-inherited is rw = False;
	has Str $.accessor-name is rw;
	has Bool $.gen-accessor is rw;
	has Code $.coerce is rw = sub ($lval is rw, Mu:U $type) { PDF::Object.coerce($lval, $type) };
        has Str @.aliases is rw;
	has $.type is rw;
	has method has_accessor { False }
    }

    my role TiedEntry does Tied {
	has Bool $.entry = True;
    }

    multi sub process-args(True, Attribute $att) {}
    multi sub process-args($entry, Attribute $att) {

	for $entry.list -> $arg {
	    unless $arg ~~ Pair {
		warn "ignoring entry trait  argument: {$arg.perl}";
		next;
	    }
	    given $arg.key {
		when 'alias'    { $att.aliases      = $arg.value.list }
		when 'inherit'  { $att.is-inherited = $arg.value }
		when 'required' { $att.is-required  = $arg.value }
		when 'indirect' { $att.is-indirect  = $arg.value }
		when 'coerce'   { $att.coerce = $arg.value }
		default         { warn "ignoring entry attribute: $_" }
	    }
	}
    }

    multi trait_mod:<is>(Attribute $att is rw, :$entry!) is export(:DEFAULT) {
	my $type = $att.type;
	$att does TiedEntry;
	my $name = $att.name;
	$att.accessor-name = $name.subst(/^(\$|\@|\%)'!'/, '');
	my $sigil = ~ $0;
	given $sigil {
	    when '$' {}
	    when '@' {
		# assert that rakudo has interpreted this as Positional[SomeType]
		die "internal error. expecting Positional role, got {$type.gist}"
		    unless $type ~~ Positional;
	    }
	    default {
		warn "ignoring '$sigil' sigil";
	    }
	}
	$att.type = $type;
	$att.gen-accessor = $att.has-accessor;
	process-args($entry, $att);
    }

    my role TiedIndex does Tied {
	has Int $.index is rw;
    }

    multi trait_mod:<is>(Attribute $att, :$index! ) is export(:DEFAULT) {
	my $type = $att.type;
	$att does TiedIndex;
	$att.accessor-name = $att.name.subst(/^(\$|\@|\%)'!'/, '');
	my $sigil = $0 && ~ $0;
	my @args = $index.list;
	die "index trait requires a UInt argument, e.g. 'is index(1)'"
	    unless @args && @args[0] ~~ UInt;
	$att.index = @args.shift;
	$att.type = $type;
	$att.gen-accessor = $att.has-accessor;
	process-args(@args, $att);
    }

    method lvalue($_) is rw {
        when PDF::Object  { $_ }
        when Hash | Array | DateTime { $.coerce($_, :$.reader) }
        default           { $_ }
    }

    multi method apply-att($lval is rw, Attribute $att) is default {
	my $type = $att.type;
	unless $lval.isa(Pair) {
	    ($att.coerce)($lval, $type)
		if $lval.defined && ! ($lval ~~ $type);
	    $lval.obj-num //= -1
		if $att.is-indirect && $lval ~~ PDF::Object;
	}
    }

    #| indirect reference
    multi method deref(Pair $ind-ref! where {.key eq 'ind-ref' && $.reader && $.reader.auto-deref}) {
        my Int $obj-num = $ind-ref.value[0];
        my Int $gen-num = $ind-ref.value[1];

        $.reader.ind-obj( $obj-num, $gen-num ).object;
    }
    #| already an object
    multi method deref(PDF::Object $value) { $value }

    #| coerce and save hash entry
    multi method deref($value where Hash | Array , :$key!) {
        self.ASSIGN-KEY($key, $value);
    }

    #| coerce and save array entry
    multi method deref($value where Hash | Array , :$pos!) {
        self.ASSIGN-POS($pos, $value);
    }

    #| simple native type. no need to coerce
    multi method deref($value) is default { $value }

    #| return a raw untied object. suitible for perl dump etc.
    method raw {

        return self
            if self !~~ Hash | Array
            || ! self.reader || ! self.reader.auto-deref;

        temp self.reader.auto-deref = False;

        my $raw;

        given self {
            when Hash {
                $raw := {};
                $raw{.key} = .value
                    for self.pairs;
            }
            when Array {
                $raw = [];
                $raw[.key] = .value
                    for self.pairs;
            }
        }
        $raw;
    }

}
