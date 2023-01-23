use v6;

class PDF::IO {
    use PDF::COS;
    # a poor man's polymorphism: allow pdf input from IO handles or strings
    # could be obseleted by cat-strings, when available
    has Str $.path is rw;

    method coerce($v is raw, |c) { self.COERCE($v, |c) }

    proto method COERCE( $value ) returns PDF::IO {*}

    multi method COERCE( PDF::IO $value!, :$path ) {
        # don't reCOERCE
        $value.path = $_ with $path;
        $value;
    }

    multi method COERCE( IO::Path $value, |c ) is hidden-from-backtrace {
	self.COERCE( $value.open( :bin, |c ) );
    }

    multi method COERCE(IO::Handle:D $_!, |c ) {
        PDF::COS.required('PDF::IO::Handle').COERCE($_, |c );
    }

    multi method COERCE( Str:D $_! where { !.isa(PDF::IO) }, |c) {
        PDF::COS.required('PDF::IO::Str').COERCE($_, |c);
    }

    multi method COERCE( Blob $_!, |c) {
        PDF::COS.required('PDF::IO::Str').COERCE($_, |c);
    }

    multi method COERCE( Failure $_) is hidden-from-backtrace {
        .throw;
    }

    multi method stream-data( List :$ind-obj! ) {
        $.stream-data( |$ind-obj[2] );
    }
    multi method stream-data( Hash :$stream! ) {
        $stream<encoded>
    }

    method substr(|c) is DEPRECATED<byte-str> { $.byte-str(|c) }

    method byte-str(|c) {
	$.subbuf(|c).decode('latin-1');
    }
}
