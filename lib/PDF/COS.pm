use v6;

our $loader;
our %required;

#| Perl 6 bindings to the Carousel Object System (http://jimpravetz.com/blog/2012/12/in-defense-of-cos/)
role PDF::COS {

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

    multi method coerce(PDF::COS $val!) { $val }

    multi method coerce(Hash $dict!, |c) {
	use PDF::Grammar:ver(v0.1.0+) :AST-Types;
        BEGIN my %ast-types = AST-Types.enums;
	+$dict == 1 && (%ast-types{$dict.keys[0]}:exists)
	    ?? $.coerce( |$dict, |c )    # JSON munged pair
	    !! $.coerce( :$dict, |c );
    }
    multi method coerce(List $array!, |c) {
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

    multi method coerce( List :$array!, |c ) {
        state $base-class = $.required('PDF::COS::Array');
        $.load-delegate( :$array, :$base-class ).new( :$array, |c );
    }

    multi method coerce( List :$ind-ref!) {
	:$ind-ref
    }

    multi method coerce( Int :$int! is rw) {
        self!add-role($int, 'PDF::COS::Int');
    }
    multi method coerce( Int :$int! is copy) { self.coerce: :$int }

    multi method coerce( Numeric :$real! is rw) {
        self!add-role($real, 'PDF::COS::Real');
    }
    multi method coerce( Numeric :$real! is copy) { self.coerce: :$real }

    multi method coerce( Str :$hex-string! is rw) {
        self!add-role($hex-string, 'PDF::COS::ByteString');
        $hex-string.type = 'hex-string';
        $hex-string;
    }
    multi method coerce( Str :$hex-string! is copy) { self.coerce: :$hex-string }

    multi method coerce( Str :$literal! is rw) {
        self!add-role($literal, 'PDF::COS::ByteString');
        $literal.type = 'literal';
        $literal;
    }
    multi method coerce( Str :$literal! is copy) { self.coerce: :$literal }

    multi method coerce( Str :$name! is rw) {
        self!add-role($name, 'PDF::COS::Name');
    }
    multi method coerce( Str :$name! is copy) { self.coerce: :$name }

    multi method coerce( Bool :$bool! is rw) {
        self!add-role($bool, 'PDF::COS::Bool');
    }
    multi method coerce( Bool :$bool! is copy) { self.coerce: :$bool }

    multi method coerce( Hash :$dict!, |c ) {
	state $base-class = $.required('PDF::COS::Dict');
	my $class = $.load-delegate( :$dict, :$base-class );
	$class.new( :$dict, |c );
    }

    multi method coerce( Hash :$stream!, |c ) {
        my %params;
        for <start end encoded decoded> -> \k {
            %params{k} = $_
                with $stream{k};
        }
        my Hash $dict = $stream<dict> // {};
        state $base-class = $.required('PDF::COS::Stream');
	my $class = $.load-delegate( :$dict, :$base-class);
        $class.new( :$dict, |%params, |c );
    }

    multi method coerce(:$null!) {
        state $ = $.required('PDF::COS::Null').new;
    }

    multi method coerce($val) is default { $val }

    method !coercer {
        state $coercer = $.required('PDF::COS::Coercer');
        $coercer;
    }

    method loader is rw {
	unless $loader.can('load-delegate') {
	    $loader = $.required('PDF::COS::Loader');
	}
	$loader
    }

    method load-delegate(|c) {
	$.loader.load-delegate(|c);
    }

}
