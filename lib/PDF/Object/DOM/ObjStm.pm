use v6;

use PDF::Object;
use PDF::Object::Stream;

# /Type /ObjStm - a stream of (usually compressed) objects
# introduced with PDF 1.5 
class PDF::Object::DOM::ObjStm
    is PDF::Object::Stream {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;

    has Int $!First; method First { self.tie($!First) };
    has Int $!N; method N { self.tie($!N) };
    has PDF::Object::Stream:_ $!Extends; method Extends { self.tie($!Extends) };

    method cb-setup-type( Hash $dict is rw ) {
        $dict<Type> = PDF::Object.compose( :name<ObjStm> );
    }

    method encode(Array $objstm = $.decoded, Bool :$check = False --> Str) {
        my @idx;
        my $objects-str = '';
        my $offset = 0;
        for $objstm.list { 
            my $obj-num = .[0];
            my $object-str = .[1];
            if $check {
                PDF::Grammar::PDF.parse( $object-str, :rule<object> )
                    // die "unable to parse type 2 object: $obj-num 0 R [from type 1 object {$.obj-num // '?'} {$.gen-num // '?'} R]\n$object-str";
            }
            @idx.push: $obj-num;
            @idx.push: $objects-str.chars;
            $objects-str ~= $object-str;
        }
        my $idx-str = @idx.join: ' ';
        self<First> = $idx-str.chars + 1;
        self<N> = +$objstm;

        nextwith( [~] $idx-str, ' ', $objects-str );
    }

    method decode($? --> Array) {
        my $chars = callsame;
        my $first = ( $.First // die "missing mandatory /ObjStm param: /First" );
        my $n = ( $.N // die "missing mandatory /ObjStm param: /N" );

        my $object-index-str = substr($chars, 0, $first - 1);
        my $objects-str = substr($chars, $first);

        my $actions = PDF::Grammar::PDF::Actions.new;
        PDF::Grammar::PDF.parse($object-index-str, :rule<object-stream-index>, :$actions)
            or die "unable to parse object stream index: $object-index-str";

        my $object-index = $/.ast;
        # these should possibly be structured exceptions
        die "problem decoding /Type /ObjStm object: $.obj-num $.gen-num R\nexpected /N = $n index entries, got {+$object-index}"
            unless +$object-index >= $n;

        [ (0 ..^ $n).map: -> $i {
            my $obj-num = $object-index[$i][0].Int;
            my $start = $object-index[$i][1];
            my $end = $object-index[$i + 1]:exists
                ?? $object-index[$i + 1][1]
                !! $objects-str.chars;
            my $length = $end - $start;
            die "problem decoding /Type /ObjStm object: $.obj-num $.gen-num R\nindex offset $start exceeds decoded data length {$objects-str.chars}"
                if $start > $objects-str.chars;
            my $object-str = $objects-str.substr( $start, $length );
            [ $obj-num, $object-str ]
        } ]
    }
}
