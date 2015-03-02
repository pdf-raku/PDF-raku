use v6;

class PDF::Object {
    method Numeric  { + $.content.value }
    method Str  { ~ $.content.value }
    method Bool { ? $.content.value }

    method serialize {
        require ::('PDF::Tools::Serializer');
        my $serializer = ::('PDF::Tools::Serializer').new;
        my $root = $serializer.freeze( self );
        my $objects =  $serializer.ind-objs;
        return %( :$root, :$objects );
    }
}
