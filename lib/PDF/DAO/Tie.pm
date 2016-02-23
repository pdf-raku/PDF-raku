use v6;
use PDF::DAO;

role PDF::DAO::Tie {

    has Attribute $.of-att is rw;      #| default attribute

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
			    # init
			    $att = Attribute.new( :name('@!' ~ $.accessor-name), :type($of-type), :package<?> );
			    $att does TiedIndex;
			    $att.tied = $.clone;
			    $att.tied.type = $of-type;
			    $lval.of-att = $att;
			
			    for $lval.values {
				next if $_ ~~ Pair | $att.tied.type;
				($att.tied.coerce)($_, $att.tied.type);
				.reader //= $reader if $reader && .can('reader');
			    }
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

	multi method apply($lval is copy) is default {
	    $.apply($lval);
	}

        multi method type-check($val, :$*key) is rw {
	    $.type-check($val, $.type)
	}

	multi method type-check($val is copy, Positional[Mu] $type) is rw {
	    if $val.defined {
		$.type-check($val, Array);
		die "array not of length: {$.length}"
		    if $.length && +$val != $.length;
		my $of-type = $type.of;
		$.type-check($_, $of-type)
		    for $val.values;
	    }
	    else {
		die "missing required field: $*key"
		    if $.is-required;
		$val = Nil;
	    }
	    $val;
	}

	multi method type-check($val is copy, Associative[Mu] $type) is rw {
	    if $val.defined {
		$.type-check($val, Hash);
		my $of-type = $type.of;
		$.type-check($_, $of-type)
		    for $val.values;
	    }
	    else {
		die "missing required field: $*key"
		    if $.is-required;
		$val = Nil
	    }
	    $val;
	}

	#| untyped attribute
	multi method type-check($val is copy, Mu $type) is rw {
	    if !$val.defined {
		die "missing required field: $*key"
		    if $.is-required;
		$val = Nil
	    }
	    $val
	}
	#| type attribute
	multi method type-check($val is copy, $type = $.type) is rw is default {
	    if $val.defined {
		die "{$val.WHAT.^name}.$*key: {$val.WHAT.gist} - not of type: {$type.gist}"
		    unless $val ~~ $type | Pair;	#| undereferenced - don't know it's type yet
	    }
	    else {
	      die "{$val.WHAT.^name}: missing required field: $*key"
		  if $.is-required;
	      $val = Nil;
	    }
	    $val;
	}

    }

    multi sub process-args(True, Attribute $att) {}
    multi sub process-args($entry, Attribute $att) {

	for $entry.list -> $arg {
	    unless $arg ~~ Pair {
		warn "ignoring entry trait  argument: {$arg.perl}";
		next;
	    }
	    my $val = $arg.value;
	    given $arg.key {
		when 'inherit'  { $att.tied.is-inherited = $val }
		when 'required' { $att.tied.is-required  = $val }
		when 'indirect' { $att.tied.is-indirect  = $val }
		when 'coerce'   { $att.tied.coerce       = $val }
                when 'len'      { $att.tied.length       = $val }
		default         { warn "ignoring entry attribute: $_" }
	    }
	}
    }

    multi trait_mod:<is>(Attribute $att, :$entry!) is export(:DEFAULT) {
	my $type = $att.type;
	my Bool $gen-accessor = $att.has_accessor;
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
		# assert that rakudo has interpreted this as Associative[SomeType]
		die "internal error. expecting Associative role, got {$type.gist}"
		    unless $type ~~ Associative;
	    }
	    default {
		warn "ignoring '$sigil' sigil";
	    }
	}
	$att.tied.type = $type;
	$att.tied.gen-accessor = $gen-accessor;
	process-args($entry, $att);
    }

    multi trait_mod:<is>(Attribute $att, :$index! ) is export(:DEFAULT) {
	my $type = $att.type;
	my Bool $gen-accessor = $att.has_accessor;
	$att does TiedIndex;
	$att.tied.accessor-name = $att.name.subst(/^(\$|\@|\%)'!'/, '');
	my $sigil = $0 && ~ $0;
	my @args = $index.list;
	die "index trait requires a UInt argument, e.g. 'is index(1)'"
	    unless @args && @args[0] ~~ UInt;
	$att.index = @args.shift;
	$att.tied.type = $type;
	$att.tied.gen-accessor = $gen-accessor;
	process-args(@args, $att);
    }

    method lvalue($_) is rw {
        when PDF::DAO  { $_ }
        when Hash | Array | DateTime { $.coerce($_, :$.reader) }
        default           { $_ }
    }

    #| indirect reference
    multi method deref(Pair $ind-ref! where {.key eq 'ind-ref'}) {
	(my Int $obj-num, my Int $gen-num, my $reader) = $ind-ref.value.list;

	$reader //= $.reader
	    // die "indirect reference without associated reader: $obj-num $gen-num R";

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
