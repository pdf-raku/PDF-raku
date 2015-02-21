use v6;

use PDF::Tools::IndObj::Stream;

# /Type /ObjStm - a stream of (usually compressed) objects
# introduced with PDF 1.5 
our class PDF::Tools::IndObj::Type::ObjStm
    is PDF::Tools::IndObj::Stream;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

method First is rw {
    %.dict<First>;
}

method N is rw {
    %.dict<N>;
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
    $.Type = :name<ObjStm>;
    $.First = :int( $idx-str.chars + 1 );
    $.N = :int( +$objstm );
    
    nextwith( [~] $idx-str, ' ', $objects-str );
}

method decode($? --> Array) {
    my $chars = callsame;
    my $first = ( $.First // die "missing mandatory /ObjStm param: /First" ).value;
    my $n = ( $.N // die "missing mandatory /ObjStm param: /N" ).value;

    my $object-index-str = substr($chars, 0, $first - 1);
    my $objects-str = substr($chars, $first);

    my $actions = PDF::Grammar::PDF::Actions.new;
    PDF::Grammar::PDF.parse($object-index-str, :rule<object-stream-index>, :$actions)
        // die "unable to parse object stream index: $object-index-str";

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
