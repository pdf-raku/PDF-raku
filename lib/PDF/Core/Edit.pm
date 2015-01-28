use v6;

enum PDF::Core::Edit::Type <Add Update Delete>;

class PDF::Core::Edit {
    has PDF::Core::Edit::Type $.edit-type;

    sub new-edit(:$edit-type!, *%opt) {
        my $class = do given ($edit-type) {
            when Add { ::('PDF::Core::Edit::Add') }
            when Update { ::('PDF::Core::Edit::Update') }
            when Delete { ::('PDF::Core::Edit::Delete') }
        }

        $class.new( :$edit-type, |%opt );
    }

}
