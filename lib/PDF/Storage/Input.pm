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
        return ::('PDF::Storage::Input::IOH').new( :$value );
    }

    multi method coerce( Str $value! where { !.isa(PDF::Storage::Input) }) {
        require ::('PDF::Storage::Input::Str');
        return ::('PDF::Storage::Input::Str').new( :$value );
    }

    multi method stream-data( Array :$ind-obj! ) {
        $.stream-data( |$ind-obj[2] );
    }
    multi method stream-data( Hash :$stream! ) {
        return $stream<encoded>
            if $stream<encoded>.defined;
        my Int $start = $stream<start>;
        my Int $end = $stream<end>;
        my Int $length = $end - $start + 1;
        $.substr($start, $length );
    }
    multi method stream-data( *@args, *%opts ) is default {

        die "unexpected arguments: {[@args].perl}"
            if @args;
        
        die "unable to handle {%opts.keys} struct: {%opts.perl}"
    }

}
