use v6;

use PDF::COS::Stream;

# /Type /XRef - cross reference stream, introduced with PDF 1.5
# see [PDF 32000 Section 7.5.8 Cross-Reference Streams]
class PDF::COS::Type::XRef
    is PDF::COS::Stream {

    use PDF::COS;
    use PDF::IO::Util :pack, :native-delegate;
    use PDF::IO::Blob;
    use PDF::COS::Tie;
    use PDF::COS::Name;

##    use ISO_32000::Table_17-Additional_entries_specific_to_a_cross-reference_stream_dictionary;
##    also does ISO_32000::Table_17-Additional_entries_specific_to_a_cross-reference_stream_dictionary;

    has PDF::COS::Name $.Type is entry(:required) where 'XRef';   #| (Required) The type of PDF object that this dictionary describes; shall be XRef for a cross-reference stream.

    has UInt $.Size is entry(:required);  #| (Required) The number one greater than the highest object number used in this section or in any section for which this is an update. It is equivalent to the Size entry in a trailer dictionary.
    has UInt @.Index is entry;            #| (Optional) An array containing a pair of integers for each subsection in this section. The first integer is the first object number in the subsection; the second integer is the number of entries in the subsection
    has UInt $.Prev is entry;             #| (Present only if the file has more than one cross-reference stream; not meaningful in hybrid-reference files) The byte offset from the beginning of the file to the beginning of the previous cross-reference stream. This entry has the same function as the Prev entry in the trailer dictionary (
    has UInt @.W is entry(:required);     #| (Required) An array of integers, each representing the size of the fields in a single cross-reference entry.

    # See [PDF 1.7 TABLE 19 Additional entries in a hybrid-reference file’s trailer dictionary]
    has UInt $.XRefStm is entry;          #| (Optional) The byte offset from the beginning of the file of a cross-reference stream.

    method first-obj-num is rw { self<Index>[0] }
    method next-obj-num is rw { self<Size> }

    method cb-init {
	self<Type> = PDF::COS::Name.COERCE: 'XRef';
        self<W> //= [ 1, 2, 1 ];
        self<Size> //= 0;
    }

    method encode(array[uint64] $xref = $.decoded --> Blob) {

        self.Index[0] //= 0;
        self.Index[1] ||= $.Size;

        die '/XRef mandatory /Index[0] entry is missing'
            without $.first-obj-num;

        die '/XRef mandatory /Size entry is missing or zero'
            unless $.next-obj-num;

        # /W resize to widest byte-widths, if needed
        my @W = packing-widths($xref, 3);
        self<W> = @W;
        my \buf := pack( $xref, @W,);

        nextwith( PDF::IO::Blob.new: buf );
    }

    sub pack-xref-stream-raku($xref-index where .shape[1] ~~ 4, @xref, @index) {
        my $size = -1;
        my $n = +$xref-index;
        for ^$n -> $i {
            my $obj-num = $xref-index[$i; 0];
            given $obj-num <=> $size {
                when More { @index.push( $obj-num, 0 ) }
                when Less { die "/XRef /Index is not sorted by ascending obj-num" }
            }
            @index.tail++;
            @xref[$i; 0] = $xref-index[$i; 1];
            @xref[$i; 1] = $xref-index[$i; 2];
            @xref[$i; 2] = $xref-index[$i; 3];
            $size = $obj-num + 1;
        }
        $size;
    }

    #= inverse of $.decode-index. calculates and sets $.Size and $.Index
    method encode-index(array[uint64] $xref-index) {
        my UInt @index;
        my $n = +$xref-index;
        my uint64 @xref[$n;3];
        my &xref-packer := native-delegate('pack-xref-stream') // &pack-xref-stream-raku;
        my $size = &xref-packer($xref-index, @xref, @index);
        self<Size> = $size;
        self<Index> = @index;

        $.encode(@xref);
    }

    method decode($? --> array[uint64]) {
        my $buf = callsame;
	$buf .= encode('latin-1')
	    if $buf.isa(Str);

        my \W = $.W
            // die "missing mandatory /XRef param: /W";
        die "missing mandatory /XRef param: /Size" without $.Size;

        my array $xref-idx = unpack( $buf, W );

        if self<Index> -> \index {
            my \n = [+] index[1, 3 ... *];
            die "problem decoding /Type /XRef object. /Index specified {n} objects, got {+$xref-idx}"
                unless +$xref-idx == n;
        }

        $xref-idx;
    }

    #= an extra decoding stage - build index entries from raw decoded data

    sub unpack-xref-stream-raku(\decoded where .shape[1] ~~ 3, \index) {
        my uint64 @index[+decoded;4];
        my uint $i = 0;
        for index.list -> $obj-num is rw, \num-entries {
            die "/XRef stream content overflow"
                if $i + num-entries > +decoded;
            for ^num-entries {
                @index[$i;0] = $obj-num;
                @index[$i;1] = decoded[$i;0];
                @index[$i;2] = decoded[$i;1];
                @index[$i;3] = decoded[$i;2];
                $obj-num++;
                $i++;
            }
        }

        @index;
    }

    method decode-index($encoded = $.encoded) {
        my Array \index = self<Index> // [ 0, $.Size ];
        my array[uint64] \decoded = $.decode( $encoded );
        my &xref-unpacker := native-delegate('unpack-xref-stream') // &unpack-xref-stream-raku;
        &xref-unpacker(decoded, index);
    }

}

