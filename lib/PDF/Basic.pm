use v6;

use PDF::Basic::Filter;
use PDF::Basic::Writer;
use PDF::Basic::Unbox;

class PDF::Basic
    is PDF::Basic::Filter
    is PDF::Basic::Writer
    is PDF::Basic::Unbox {

    has Str $.input;  # raw PDF image (latin-1 encoding)
    has Hash %.ind-obj-idx;

    submethod BUILD(Hash :$root, Str :$!input) {

        if $root.defined {
            for $root<body>.list  {
                #= build object index
                for <objects>.list {
                    next unless my $ind-obj = .<ind-obj>;
                    my $obj-num = $ind-obj[0].Int;
                    my $gen-num = $ind-obj[1].Int;
                    %!ind-obj-idx{$obj-num}{$gen-num} = $ind-obj;
                }
            }
        }
    }

}
