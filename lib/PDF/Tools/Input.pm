use v6;

class PDF::Tools::Input {
    # a poor mans polymorphism: allow pdf input from IO handles or strings
    # could be obseleted by cat-strings, when available

    multi method compose( PDF::Tools::Input :$value! ) {
        # don't recompose
        $value;
    }

    multi method compose( IO::Handle :$value! ) {
        require ::('PDF::Tools::Input::IOH');
        return ::('PDF::Tools::Input::IOH').new( :$value );
    }

    multi method compose( Str :$value! ) {
        require ::('PDF::Tools::Input::Str');
        return ::('PDF::Tools::Input::Str').new( :$value );
    }

    multi method stream-data( Array :$ind-obj! ) {
        $.stream-data( |$ind-obj[2] );
    }
    multi method stream-data( Hash :$stream! ) {
        return $stream<encoded>
            if $stream<encoded>.defined;
        my $start = $stream<start>;
        my $end = $stream<end>;
        my $length = $end - $start + 1;
        $.substr($start, $length );
    }
    multi method stream-data( *@args, *%opts ) is default {

        die "unexpected arguments: {[@args].perl}"
            if @args;
        
        die "unable to handle {%opts.keys} struct: {%opts.perl}"
    }

}
