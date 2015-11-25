use v6;
use PDF::DAO;

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

role PDF::DAO::Tie {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;
    has Attribute $.of-att is rw;      #| default attribute

    method is-indirect is rw returns Bool {
	Proxy.new(
	    FETCH => method { ?$.obj-num },
	    STORE => method (Bool $val) {
		if $val {
		    # Ensure this object is indirect. Serializer will renumber
		    $.obj-num //= -1;
		}
		else {
		    $.obj-num = Nil;
		}
		$val
	    },
	    );
    }

    #| generate an indirect reference to ourselves
    method ind-ref {
	die "not an indirect obect"
	    unless $.obj-num && $.obj-num > 0;
	:ind-ref[ $.obj-num, $.gen-num ];
    }

    #| generate an indirect reference, include the reader, if spanning documents
    method link { 
	my $obj-num = $.obj-num;
	$obj-num && $obj-num > 0
	    ?? :ind-ref[ $obj-num, $.gen-num, $.reader ]
	    !! self
    }

    my class Tied {...}

    my role TiedEntry {
	has Tied $.tied handles <apply> = Tied.new;
	has method has_accessor { False }
	has Bool $.entry = True;
    }

    my role TiedIndex {
	has Tied $.tied is rw handles <apply> = Tied.new;
	has method has_accessor { False }
	has UInt $.index is rw;
    }

    my class Tied {
	has $.type is rw;
	has Bool $.is-required is rw = False;
	has Bool $.is-indirect is rw = False;
	has Bool $.is-inherited is rw = False;
	has Str $.accessor-name is rw;
	has Bool $.gen-accessor is rw;
	has Code $.coerce is rw = sub ($lval is rw, Mu:U $type) { PDF::DAO.coerce($lval, $type) };
        has Str @.aliases is rw;
        has UInt $.length is rw;

	use nqp;

	multi method apply($lval is rw where { nqp::isrwcont($lval) } ) {
	    my $type = $.type;
	    unless $lval.isa(Pair) {
		if $lval.defined && ! ($lval ~~ $type) {

		    my $reader  = $lval.?reader;
		    my $obj-num = $lval.?obj-num;
		    my $gen-num = $lval.?gen-num;

		    if ($type ~~ Positional[Mu] && $lval ~~ Array)
                    || ($type ~~ Associative[Mu] && $lval ~~ Hash) {
			# of-att array declaration, e.g.:
			# has PDF::DOM::Type::Catalog @.Kids is entry(:indirect);
                        # or, associative hash declarations, e.g.:
                        # has PDF::DOM::Type::ExtGState %.ExtGState is entry;
			my $of-type = $type.of;
			my $att = $lval.of-att;
			if $att {
			    die "conflicting types for {$att.name} {$att.type.gist} {$of-type.gist}"
				unless $of-type ~~ $att.type;
			}
			else {
			    $att = Attribute.new( :name('@!' ~ $.accessor-name), :type($type.of), :package<?> );
			    $att does TiedIndex;
			    $att.tied = $.clone;
			    $att.tied.type = $of-type;
			    $lval.of-att = $att;
			}
			
			for $lval.values {
			    next if $_ ~~ Pair | $att.tied.type;
			    ($att.tied.coerce)($_, $att.tied.type);
			     .reader //= $reader if $reader && .can('reader');
			}
		    }
		    else {
			($.coerce)($lval, $type);
			$lval.reader  //= $reader  if $reader.defined;
			$lval.obj-num //= $obj-num if $obj-num.defined;
			$lval.gen-num //= $gen-num if $gen-num.defined;
		    }
		}
		else {
		    $lval.obj-num //= -1
			if $.is-indirect && $lval ~~ PDF::DAO;
		}
	    }
	    $lval;
	}

	multi method apply($lval is copy ) is default {
	    $.apply($lval);
	}
    }

    multi sub process-args(True, Attribute $att) {}
    multi sub process-args($entry, Attribute $att) {

	for $entry.list -> $arg {
	    unless $arg ~~ Pair {
		warn "ignoring entry trait  argument: {$arg.perl}";
		next;
	    }
	    given $arg.key {
		when 'alias'    { $att.tied.aliases      = $arg.value.list }
		when 'inherit'  { $att.tied.is-inherited = $arg.value }
		when 'required' { $att.tied.is-required  = $arg.value }
		when 'indirect' { $att.tied.is-indirect  = $arg.value }
		when 'coerce'   { $att.tied.coerce = $arg.value }
                when 'len'      { $att.tied.length = $arg.value }
		default         { warn "ignoring entry attribute: $_" }
	    }
	}
    }

    multi trait_mod:<is>(Attribute $att, :$entry!) is export(:DEFAULT) {
	my $type = $att.type;
	$att does TiedEntry;
	my $name = $att.name;
	$att.tied.accessor-name = $name.subst(/^(\$|\@|\%)'!'/, '');
	my $sigil = ~ $0;
	given $sigil {
	    when '$' {}
	    when '@' {
		# assert that rakudo has interpreted this as Positional[SomeType]
		die "internal error. expecting Positional role, got {$type.gist}"
		    unless $type ~~ Positional;
	    }
	    when '%' {
		# assert that rakudo has interpreted this as Positional[SomeType]
		die "internal error. expecting Associative role, got {$type.gist}"
		    unless $type ~~Associative;
	    }
	    default {
		warn "ignoring '$sigil' sigil";
	    }
	}
	$att.tied.type = $type;
	$att.tied.gen-accessor = $att.has-accessor;
	process-args($entry, $att);
    }

    multi trait_mod:<is>(Attribute $att, :$index! ) is export(:DEFAULT) {
	my $type = $att.type;
	$att does TiedIndex;
	$att.tied.accessor-name = $att.name.subst(/^(\$|\@|\%)'!'/, '');
	my $sigil = $0 && ~ $0;
	my @args = $index.list;
	die "index trait requires a UInt argument, e.g. 'is index(1)'"
	    unless @args && @args[0] ~~ UInt;
	$att.index = @args.shift;
	$att.tied.type = $type;
	$att.tied.gen-accessor = $att.has-accessor;
	process-args(@args, $att);
    }

    method lvalue($_) is rw {
        when PDF::DAO  { $_ }
        when Hash | Array | DateTime { $.coerce($_, :$.reader) }
        default           { $_ }
    }

    #| indirect reference
    multi method deref(Pair $ind-ref! where {.key eq 'ind-ref'}) {
	my $ref = $ind-ref.value;
        my Int $obj-num = $ref[0];
        my Int $gen-num = $ref[1];
	my $reader      = $ref > 2
	    ?? $ind-ref.value[2]
	    !! $.reader;

        die "indirect reference without associated reader: $obj-num $gen-num R"
            unless $reader;

	$reader.auto-deref
	    ?? $reader.ind-obj( $obj-num, $gen-num ).object
	    !! $ind-ref;
    }
    #| already an object
    multi method deref(PDF::DAO $value) { $value }

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

}
