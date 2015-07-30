use v6;

use PDF::Object;

role PDF::Object::Tie {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has Int $.gen-num is rw;

    role TiedEntry {
	has Bool $.entry = True;
	has Bool $.is-required is rw;
	has Bool $.is-indirect is rw;
	has Bool $.gen-accessor is rw;
	# turn off rakudo accessor generation
	has method has_accessor { False }
    }

    multi trait_mod:<is>(Attribute $att is rw, :$entry!) is export(:DEFAULT) {
	my $gen-accessor = $att.has-accessor;
	$att does TiedEntry;
	$att.is-required = ?('required' ∈ $entry);
	$att.is-indirect = ?('indirect' ∈ $entry);
	$att.gen-accessor = $gen-accessor;
    }

    role TiedIndex {
	has Int $.index is rw;
	has Bool $.is-required is rw;
	has Bool $.gen-accessor is rw;
	# turn off rakudo accessor generation
	has method has_accessor { False }
    }

    multi trait_mod:<is>(Attribute $att, :$index! ) is export(:DEFAULT) {
	my $gen-accessor = $att.has-accessor;
	die "trait usage: index(Int n, :required, :indirect)"
	    unless $index[0] ~~ Int
	    && $index[0] >= 0;
	$att does TiedIndex;
	$att.index = $index[0];
	$att.is-required = ?('required' ∈ $index);
	$att.gen-accessor = $gen-accessor;
    }

    # coerce Hash & Array assignments to objects
    multi method coerce(PDF::Object $val!) { $val }
    multi method coerce(Hash $val!) {
        PDF::Object.compose( :dict($val), :$.reader )
    }
    multi method coerce(Array $val!) {
        PDF::Object.compose( :array($val), :$.reader )
    }
    multi method coerce($val) is default { $val }

    method lvalue($_) is rw {
        when PDF::Object  { $_ }
        when Hash | Array { $.coerce($_) }
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
