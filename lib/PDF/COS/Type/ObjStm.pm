use v6;

use PDF::COS;
use PDF::COS::Stream;
use PDF::COS::Tie::Hash;

# /Type /ObjStm - a stream of (usually compressed) objects
# introduced with PDF 1.5 
# See [PDF 1.7 Section 3.4.6 Object Streams]
class PDF::COS::Type::ObjStm
    is PDF::COS::Stream
    does PDF::COS::Tie::Hash {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::COS::Tie;
    use PDF::COS::Name;

    # see [PDF 1.7 TABLE 16 Additional entries specific to an object stream dictionary]
    my subset Name-ObjStm of PDF::COS::Name where 'ObjStm';
    has Name-ObjStm $.Type is entry( :required ); #| (Required) The type of PDF object that this dictionary describes; shall be ObjStm for an object stream.
    has UInt $.N is entry(:required);             #| (Required) The number of compressed objects in the stream.
    has UInt $.First is entry(:required);         #| (Required) The byte offset (in the decoded stream) of the first compressed object.
    has PDF::COS::Stream $.Extends is entry;      #| (Optional) A reference to an object stream, of which the current object stream is considered an extension

    method cb-init {
        self<Type> //= PDF::COS.coerce( :name<ObjStm> );
	self<N> //= 0;
	self<First> //= 0;
    }

    method encode(Array $objstm = $.decoded, Bool :$check = False) {
        my uint @idx;
        my Str $objects-str = '';
        for $objstm.list { 
            my UInt \obj-num = .[0];
            my Str \object-str = .[1];
            if $check {
                PDF::Grammar::PDF.parse( object-str, :rule<object> )
                    // die "unable to parse type 2 object: {obj-num} 0 R [from type 1 object {$.obj-num // '?'} {$.gen-num // '?'} R]\n{object-str}";
            }
            @idx.push: obj-num;
            @idx.push: $objects-str.codes;
            $objects-str ~= \object-str;
        }
        my Str \idx-str = @idx.join: ' ';
        self<First> = idx-str.codes + 1;
        self<N> = +$objstm;

        nextwith( [~] (idx-str, ' ', $objects-str) );
    }

    method decode($? --> Array) {
        my \bytes = callsame;
        my UInt \first = $.First;
        my UInt \n = $.N;

        my Str \object-index-str = bytes.substr(0, first - 1);

        my PDF::Grammar::PDF::Actions $actions .= new;
        PDF::Grammar::PDF.parse(object-index-str, :rule<object-stream-index>, :$actions)
            or die "unable to parse object stream index: {object-index-str}";

        my Array \object-index = $/.ast;
        # these should possibly be structured exceptions
        die "problem decoding /Type /ObjStm object: $.obj-num $.gen-num R\nexpected /N = {n} index entries, got {+object-index}"
            unless +object-index >= n;

        [ (0 ..^ n).map: -> \i {
            my UInt \obj-num = object-index[i][0].Int;
            my UInt \begin = first + object-index[i][1];
            my UInt \end = object-index[i + 1]:exists
                ?? first + object-index[i + 1][1]
                !! bytes.codes;
            my Int \length = end - begin;
            die "problem decoding /Type /ObjStm object: $.obj-num $.gen-num R\nindex offset {begin} exceeds decoded data length {bytes.codes}"
                if begin > bytes.codes;
            my Str \object-str = bytes.substr( begin, length );
            [ obj-num, object-str ]
        } ]
    }
}
