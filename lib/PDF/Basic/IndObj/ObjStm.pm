use v6;

use PDF::Basic::IndObj::Stream;

# /Type /ObjStm - a stream of (usually compressed) objects
# introduced with PDF 1.5 
our class PDF::Basic::IndObj::ObjStm
    is PDF::Basic::IndObj::Stream;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Basic::Writer;

method First is rw {
    %.dict<First>;
}

method N is rw {
    %.dict<N>;
}

method encode($objstm = $.decoded --> Str) {
    my @idx;
    my $objects-str = '';
    my $offset = 0;
    for $objstm.list { 
        my $obj-num = .<obj-num>;
        my $object = .<object>;
        my $object-str = 
        @idx.push: $obj-num;
        @idx.push: $objects-str.chars;
        $objects-str ~= PDF::Basic::Writer.write-obj( $object );
    }
    my $idx-str = @idx.join: ' ';
    $.Type = 'ObjStm';
    $.First = $idx-str.chars + 1;
    $.N = +$objstm;
    
    nextwith( [~] $idx-str, ' ', $objects-str );
}

method decode($? --> Array) {
    my $chars = callsame;
    my $first = $.First
        // die "missing mandatory /ObjStm param: /First";
    my $n = $.N
        // die "missing mandatory /ObjStm param: /N";

    my $object-index-str = substr($chars, 0, $first - 1);
    my $objects-str = substr($chars, $first);

    my $actions = PDF::Grammar::PDF::Actions.new;
    PDF::Grammar::PDF.parse($object-index-str, :rule<object-stream-index>, :$actions)
        // die "unable to parse object stream index: $object-index-str";
    my $object-index = $/.ast;
    [ $object-index.keys.map: -> $i {
        my $obj-num = $object-index[$i][0].Int;
        my $start = $object-index[$i][1];
        my $end = $object-index[$i + 1]:exists
            ?? $object-index[$i + 1][1]
            !! $objects-str.chars;
        my $length = $end - $start;
        my $object-str = $objects-str.substr( $start, $length );
        PDF::Grammar::PDF.parse($object-str, :rule<object>, :$actions)
            // die "unable to parse object: $object-str";
        my $object = $/.ast;
        { :$obj-num, :$object }
    } ]
}
