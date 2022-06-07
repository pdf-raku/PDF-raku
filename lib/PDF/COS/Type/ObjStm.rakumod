use v6;

use PDF::COS::Stream;

class X::PDF::ObjStm is Exception {
    has Str $.details;
    has UInt $.obj-num;
    has UInt $.gen-num;
}

class X::PDF::ObjStm::Decode is X::PDF::ObjStm {
    method message { "Problem decoding /Type /ObjStm object: $.obj-num $.gen-num R\n$.details" }
}

class X::PDF::ObjStm::Encode is X::PDF::ObjStm {
    method message { "Problem encoding /Type /ObjStm object: $.obj-num $.gen-num R\n$.details" }
}

class PDF::COS::Type::ObjStm
    is PDF::COS::Stream {

    use PDF::COS;
    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;
    use PDF::COS::Tie;
    use PDF::COS::Name;

##    use ISO_32000::Table_16-Additional_entries_specific_to_an_object_stream_dictionary;
##    also does ISO_32000::Table_16-Additional_entries_specific_to_an_object_stream_dictionary;

    has PDF::COS::Name $.Type is entry( :required ) where 'ObjStm'; #| (Required) The type of PDF object that this dictionary describes; shall be ObjStm for an object stream.
    has UInt $.N is entry(:required);             #| (Required) The number of compressed objects in the stream.
    has UInt $.First is entry(:required);         #| (Required) The byte offset (in the decoded stream) of the first compressed object.
    has PDF::COS::Stream $.Extends is entry;      #| (Optional) A reference to an object stream, of which the current object stream is considered an extension

    method cb-init {
        self<Type> //= PDF::COS::Name.COERCE: 'ObjStm';
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
                    // die X::PDF::ObjStm::Encode.new( :$.obj-num, :$.gen-num, :details("Unable to parse object: {obj-num} 0 R: {object-str}"));
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

        my Str \object-index-str = bytes.substr(0, first);
        my PDF::Grammar::PDF::Actions $actions .= new: :lite;
        PDF::Grammar::PDF.parse(object-index-str, :rule<object-stream-index>, :$actions)
            or die X::PDF::ObjStm::Decode.new( :$.obj-num, :$.gen-num, :details("Unable to parse object stream index: {object-index-str}"));

        my Array \object-index = $/.ast;
        die X::PDF::ObjStm::Decode.new( :$.obj-num, :$.gen-num, :details("Expected /N = {n} index entries, got {+object-index}"))
            unless +object-index >= n;

        [ (^n).map: -> \i {
            my UInt \obj-num = object-index[i][0];
            my UInt \begin = first + object-index[i][1];
            my UInt \end = ((i+2) <= +object-index)
                ?? first + object-index[i + 1][1]
                !! bytes.codes;
            my Int \length = end - begin;
            die X::PDF::ObjStm::Decode.new( :$.obj-num, :$.gen-num, :details("Index offset {begin} exceeds decoded data length {bytes.codes}"))
                if begin > bytes.codes;
            die X::PDF::ObjStm::Decode.new( :$.obj-num, :$.gen-num, :details("Offsets are not in ascending order"))
                if length <= 0;
            my Str \object-str = bytes.substr( begin, length );
            [ obj-num, object-str ]
        } ]
    }
}
