use v6;

use PDF::COS::Stream;

# /Type /XRef - cross reference stream, introduced with PDF 1.5
# see [PDF 1.7 Section 3.4.7 Cross-Reference Streams]
class PDF::COS::Type::XRef
    is PDF::COS::Stream {

    use PDF::COS;
    use PDF::IO::Util :pack;
    use PDF::IO::Blob;
    use PDF::COS::Tie;
    use PDF::COS::Name;

    # See [PDF 1.7 TABLE 17 Additional entries specific to a cross-reference stream dictionary]
    has PDF::COS::Name $.Type is entry(:required) where 'XRef';   #| (Required) The type of PDF object that this dictionary describes; shall be XRef for a cross-reference stream.

    has UInt $.Size is entry(:required);  #| (Required) The number one greater than the highest object number used in this section or in any section for which this is an update. It is equivalent to the Size entry in a trailer dictionary.
    # rakudo 2015.07.1-12-g174049f; Index is a reserved attribute
    has UInt @.Index is entry;            #| (Optional) An array containing a pair of integers for each subsection in this section. The first integer is the first object number in the subsection; the second integer is the number of entries in the subsection
    has UInt $.Prev is entry;             #| (Present only if the file has more than one cross-reference stream; not meaningful in hybrid-reference files) The byte offset from the beginning of the file to the beginning of the previous cross-reference stream. This entry has the same function as the Prev entry in the trailer dictionary (
    has UInt @.W is entry(:required);     #| (Required) An array of integers, each representing the size of the fields in a single cross-reference entry.

    # See [PDF 1.7 TABLE 19 Additional entries in a hybrid-reference file’s trailer dictionary]
    has UInt $.XRefStm is entry;          #| (Optional) The byte offset from the beginning of the file of a cross-reference stream.

    method first-obj-num is rw { self<Index>[0] }
    method next-obj-num is rw { self<Size> }

    method cb-init {
	self<Type> = PDF::COS.coerce( :name<XRef> );
        self<W> //= [ 1, 2, 1 ];
        self<Size> //= 0;
    }

    method encode(array $xref = $.decoded --> Blob) {

        self.Index[0] //= 0;
        self.Index[1] ||= $.Size;

        die 'mandatory /Index[0] entry is missing'
            without $.first-obj-num;

        die 'mandatory /Size entry is missing or zero'
            unless $.next-obj-num;

        my uint32 @width;
        for $xref.pairs {
            my $v = .value;
            given @width[.key[1]] {
                $_ = $v if $v > $_
            }
        }

        # /W resize to widest byte-widths, if needed
        my UInt @W = @width.map: {
            when * < 256 { 1 }
            when * < 65536 { 2 }
            when * < 16777216 { 3 }
            default { 4 }
        };
        self<W> = @W;

        my \buf := pack( $xref, @W,);
        nextwith( PDF::IO::Blob.new: buf );
    }

    #= inverse of $.decode-index . handily calculates and sets $.Size and $.Index
    method encode-index(Array[array] $xref-index) {
        my $size = 1;
        my UInt @index;
        my uint32 @encoded-index = [];

        my @entries = $xref-index.list.sort: { $^a[0] <=> $^b[0] };

        for @entries {
            my @entry = .list;
            my $obj-num = @entry.shift;
            my Bool \contiguous = ?( $obj-num == $size );
            @index.push( $obj-num, 0 )
                unless contiguous;
            @index.tail++;
            @encoded-index.append: @entry;
            $size = $obj-num + 1;
        }

        self<Size> = $size;
        self<Index> = @index;

        my uint32 @shaped-index[+@encoded-index div 3;3] Z= @encoded-index;
        $.encode(@shaped-index);
    }

    method decode($? --> array) {
        my $buf = callsame;
	$buf = $buf.encode('latin-1')
	    if $buf.isa(Str);

        my \W = $.W
            // die "missing mandatory /XRef param: /W";
        die "missing mandatory /XRef param: /Size" without $.Size;

        my array $xref-idx = unpack( $buf, W );

        if my \index = self<Index> {
            my \n = [+] index[1, 3 ... *];
            die "problem decoding /Type /XRef object. /Index specified {n} objects, got {+$xref-idx}"
                unless +$xref-idx == n;
        }

        $xref-idx;
    }

    #= an extra decoding stage - build index entries from raw decoded data
    multi method decode-index($encoded = $.encoded) {

        my Array \index = self<Index> // [ 0, $.Size ];
        my array \decoded = $.decode( $encoded );
        my array @decoded-index = [];

        for index.list -> $obj-num is rw, \num-entries {

            for 0 ..^ num-entries -> uint $i {

                my uint32 @xref = $obj-num, decoded[$i;0], decoded[$i;1], decoded[$i;2];
                @decoded-index.push: @xref;
                $obj-num++;
            }
        }

        @decoded-index;
    }

}

