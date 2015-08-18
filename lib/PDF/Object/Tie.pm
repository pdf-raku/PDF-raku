use v6;

use PDF::Object;

role PDF::Object::Tie {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

    method ind-ref {
	die "not an indirect obect"
	    unless $.obj-num && $.obj-num > 0;
	:ind-ref[ $.obj-num, $.gen-num ];
    }

    my role Tied {
	has Bool $.is-required is rw;
	has Bool $.is-indirect is rw;
	has Str $.accessor-name is rw;
	has Bool $.gen-accessor is rw;
        has Str @.aliases is rw;
	has @.does is rw;
	# turn off rakudo accessor generation
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
		when 'alias'    { $att.aliases     = $arg.value.list }
		when 'does'     { $att.does        = ( $arg.value ) }
		when 'required' { $att.is-required = $arg.value }
		when 'indirect' { $att.is-indirect = $arg.value }
		default    { warn "ignoring entry attribute: $_" }
	    }
	}
    }

    multi trait_mod:<is>(Attribute $att is rw, :$entry!) is export(:DEFAULT) {
	$att does TiedEntry;
	$att.accessor-name = $att.name.subst(/^'$!'/, '');
	$att.gen-accessor = $att.has-accessor;
	process-args($entry, $att);
    }

    my role TiedIndex does Tied {
	has Int $.index is rw;
    }

    multi trait_mod:<is>(Attribute $att, :$index! ) is export(:DEFAULT) {
	$att does TiedIndex;
	$att.accessor-name = $att.name.subst(/^'$!'/, '');
	$att.gen-accessor = $att.has-accessor;
	my @args = $index.list;
	die "index trait requires a UInt argument, e.g. 'is index(1)'"
	    unless @args && @args[0] ~~ UInt;
	$att.index = @args.shift;

	process-args(@args, $att);
    }

    method lvalue($_) is rw {
        when PDF::Object  { $_ }
        when Hash | Array { $.coerce($_, :$.reader) }
        default           { $_ }
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
