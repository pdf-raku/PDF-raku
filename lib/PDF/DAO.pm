use v6;

our $loader;
our %required;

role PDF::DAO {

    has $.reader is rw;
    has Int $.obj-num is rw;
    has UInt $.gen-num is rw;

    method is-indirect is rw returns Bool {
	Proxy.new(
	    FETCH => sub (\p) { ? self.obj-num },
	    STORE => sub (\p, Bool \indirect) {
		if indirect {
		    # Ensure this object is indirect. Serializer will renumber
		    self.obj-num //= -1;
		}
		else {
		    self.obj-num = Nil;
		}
	    },
	    );
    }

    multi method coerce(Mu $obj is rw, Mu $type ) {
	self!coercer.coerce( $obj, $type )
    }
    multi method coerce(Mu $obj, Mu $type ) {
	self!coercer.coerce( $obj, $type )
    }

    multi method coerce(PDF::DAO $val!) { $val }

    multi method coerce(Hash $dict!, |c) {
	use PDF::Grammar:ver(v0.1.0+) :AST-Types;
        BEGIN my %ast-types = AST-Types.enums;
	+$dict == 1 && (%ast-types{$dict.keys[0]}:exists)
	    ?? $.coerce( |$dict, |c )    # JSON munged pair
	    !! $.coerce( :$dict, |c );
    }
    multi method coerce(Array $array!, |c) {
        $.coerce( :$array, |c )
    }
    multi method coerce(DateTime $dt, |c) {
	self!coercer.coerce( $dt, DateTime, |c)
    }
    multi method coerce(Pair %_!, |c) {
	$.coerce( |%_, |c)
    }
    #| work around rakudo performance regressions - issue #15
    method required(Str \mod-name) {
	if %required{mod-name}:exists {
            %required{mod-name};
        }
        else {
            %required{mod-name} = (require ::(mod-name));
	}
    }
    method !add-role($obj is rw, Str $role-name) {
	my $role = $.required($role-name);
	$obj.does($role)
            ?? $obj
            !! $obj = $obj but $role
    }

    multi method coerce( Array :$array!, |c ) {
        state $fallback = $.required('PDF::DAO::Array');
        $.load( :$array, :$fallback ).new( :$array, |c );
    }

    multi method coerce( Array :$ind-ref!) {
	:$ind-ref
    }

    multi method coerce( Int :$int! is rw) {
        self!add-role($int, 'PDF::DAO::Int');
    }
    multi method coerce( Int :$int! is copy) { self.coerce: :$int }

    multi method coerce( Numeric :$real! is rw) {
        self!add-role($real, 'PDF::DAO::Real');
    }
    multi method coerce( Numeric :$real! is copy) { self.coerce: :$real }

    multi method coerce( Str :$hex-string! is rw) {
        self!add-role($hex-string, 'PDF::DAO::ByteString');
        $hex-string.type = 'hex-string';
        $hex-string;
    }
    multi method coerce( Str :$hex-string! is copy) { self.coerce: :$hex-string }

    multi method coerce( Str :$literal! is rw) {
        self!add-role( $literal, 'PDF::DAO::ByteString');
        $literal.type = 'literal';
        $literal;
    }
    multi method coerce( Str :$literal! is copy) { self.coerce: :$literal }

    multi method coerce( Str :$name! is rw) {
        self!add-role($name, 'PDF::DAO::Name');
    }
    multi method coerce( Str :$name! is copy) { self.coerce: :$name }

    multi method coerce( Bool :$bool! is rw) {
        self!add-role($bool, 'PDF::DAO::Bool');
    }
    multi method coerce( Bool :$bool! is copy) { self.coerce: :$bool }

    multi method coerce( Hash :$dict!, |c ) {
	state $fallback = $.required('PDF::DAO::Dict');
	my $class = $.load( :$dict, :$fallback );
	$class.new( :$dict, |c );
    }

    multi method coerce( Hash :$stream!, |c ) {
        my %params;
        for <start end encoded decoded> -> \k {
            %params{k} = $_
                with $stream{k};
        }
        my Hash $dict = $stream<dict> // {};
        state $fallback = $.required('PDF::DAO::Stream');
	my $class = $.load( :$dict, :$fallback );
        $class.new( :$dict, |%params, |c );
    }

    multi method coerce(:$null!) {
        state $ = $.required('PDF::DAO::Null').new;
    }

    multi method coerce($val) is default { $val }

    method !coercer {
        state $coercer = $.required('PDF::DAO::Coercer');
        $coercer;
    }

    method loader is rw {
	unless $loader.can('load') {
	    $loader = $.required('PDF::DAO::Loader');
	}
	$loader
    }
    method load(|c) {
	$.loader.load(|c);
    }

}
