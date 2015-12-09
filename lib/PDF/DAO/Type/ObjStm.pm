use v6;

use PDF::DAO;
use PDF::DAO::Stream;
use PDF::DAO::Tie::Hash;

# /Type /ObjStm - a stream of (usually compressed) objects
# introduced with PDF 1.5 
# See [PDF 1.7 Section 3.4.6 Object Streams]
role PDF::DAO::Type::ObjStm
    is PDF::DAO::Stream
    does PDF::DAO::Tie::Hash {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::DAO::Tie;

    # see [PDF 1.7 TABLE 3.14 Additional entries specific to an object stream dictionary]
    has UInt $.N is entry(:required);         #| (Required) The number of compressed objects in the stream.
    has UInt $.First is entry(:required);     #| (Required) The byte offset (in the decoded stream) of the first compressed object.
    has PDF::DAO::Stream $.Extends is entry;  #| (Optional) A reference to an object stream, of which the current object stream is considered an extension

    method cb-init {
	self.N //= 0;
	self.First //= 0;
        self.Type //= PDF::DAO.coerce( :name<ObjStm> );
    }

    method encode(Array $objstm = $.decoded, Bool :$check = False) {
        my UInt @idx;
        my Str $objects-str = '';
        my UInt $offset = 0;
        for $objstm.list { 
            my UInt $obj-num = .[0];
            my Str $object-str = .[1];
            if $check {
                PDF::Grammar::PDF.parse( $object-str, :rule<object> )
                    // die "unable to parse type 2 object: $obj-num 0 R [from type 1 object {$.obj-num // '?'} {$.gen-num // '?'} R]\n$object-str";
            }
            @idx.push: $obj-num;
            @idx.push: $objects-str.chars;
            $objects-str ~= $object-str;
        }
        my Str $idx-str = @idx.join: ' ';
        self<First> = $idx-str.chars + 1;
        self<N> = +$objstm;

        nextwith( [~] $idx-str, ' ', $objects-str );
    }

    method decode($? --> Array) {
        my Blob $chars = callsame;
        my UInt $first = $.First;
        my UInt $n = $.N;

        my Str $object-index-str = substr($chars, 0, $first - 1);
        my Str $objects-str = substr($chars, $first);

        my $actions = PDF::Grammar::PDF::Actions.new;
        PDF::Grammar::PDF.parse($object-index-str, :rule<object-stream-index>, :$actions)
            or die "unable to parse object stream index: $object-index-str";

        my Array $object-index = $/.ast;
        # these should possibly be structured exceptions
        die "problem decoding /Type /ObjStm object: $.obj-num $.gen-num R\nexpected /N = $n index entries, got {+$object-index}"
            unless +$object-index >= $n;

        [ (0 ..^ $n).map: -> $i {
            my UInt $obj-num = $object-index[$i][0].Int;
            my UInt $start = $object-index[$i][1];
            my UInt $end = $object-index[$i + 1]:exists
                ?? $object-index[$i + 1][1]
                !! $objects-str.chars;
            my Int $length = $end - $start;
            die "problem decoding /Type /ObjStm object: $.obj-num $.gen-num R\nindex offset $start exceeds decoded data length {$objects-str.chars}"
                if $start > $objects-str.chars;
            my Str $object-str = $objects-str.substr( $start, $length );
            [ $obj-num, $object-str ]
        } ]
    }
}
