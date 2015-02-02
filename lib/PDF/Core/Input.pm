use v6;

class PDF::Core::Input {
    # a poor mans polymorphism: allow pdf input from IO handles or strings
    # could be obseleted by cat-strings, when available

    multi method new-delegate( IO::Handle :$value! ) {
        require ::('PDF::Core::Input::IOH');
        return ::('PDF::Core::Input::IOH').new( :$value );
    }

    multi method new-delegate( Str :$value! ) {
        require ::('PDF::Core::Input::Str');
        return ::('PDF::Core::Input::Str').new( :$value );
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
        $.substr($start - 1, $length - 1 );
    }
    multi method stream-data( *@args, *%opts ) is default {

        die "unexpected arguments: {[@args].perl}"
            if @args;
        
        die "unable to handle {%opts.keys} struct: {%opts.perl}"
    }

}
