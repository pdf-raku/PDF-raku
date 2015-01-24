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

}
