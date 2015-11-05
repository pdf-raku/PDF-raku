use v6;

class PDF::Storage::Input {
    # a poor mans polymorphism: allow pdf input from IO handles or strings
    # could be obseleted by cat-strings, when available

    proto method coerce( $value ) returns PDF::Storage::Input {*}

    multi method coerce( PDF::Storage::Input $value! ) {
        # don't recoerce
        $value;
    }

    multi method coerce( IO::Path $value ) {
	self.coerce( $value.open( :enc<latin-1> ) );
    }

    multi method coerce( IO::Handle $value! ) {
        require ::('PDF::Storage::Input::IOH');
        ::('PDF::Storage::Input::IOH').bless( :$value );
    }

    multi method coerce( Str $value! where { !.isa(PDF::Storage::Input) }) {
        require ::('PDF::Storage::Input::Str');
        ::('PDF::Storage::Input::Str').bless( :$value );
    }

    multi method stream-data( Array :$ind-obj! ) {
        $.stream-data( |$ind-obj[2] );
    }
    multi method stream-data( Hash :$stream! ) is default {
        $stream<encoded>
    }

}
