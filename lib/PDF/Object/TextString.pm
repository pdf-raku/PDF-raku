use v6;

use PDF::Object;

class PDF::Object::TextString
    is PDF::Object
    is Str {

=begin pod

See [PDF 1.7 TABLE 3.31 PDF data types]

text-string: Bytes that represent characters encoded
using either PDFDocEncoding or UTF-16BE with a leading byte-order marker

=end pod

    method new( Str :$value! is copy ) {
        if $value ~~ s/^ $<bom>=[\xFE \xFF]// {
            $value = $value.ords.map( -> $b1, $b2 {
            chr($b1 +< 8  +  $b2)
           }).join: '';
        }
        nextwith( :$value );
    }

    our sub utf16-encode(Str $str --> Str) {
         constant BOM = "\xFE\xFF";
         constant OverflowChar = "\xFF\xFD";
	 my Str $utf16 = $str.ords.map( -> $ord {
                   my $lo = $ord mod 0x100;
                   my $hi = $ord div 0x100;
                   my $ch = $hi < 0x100
		       ?? $hi.chr ~ $lo.chr
		       !! OverflowChar; # � for overflpw
	 }).join('');

	 BOM ~ $utf16;
    }

    method content {
        my $literal = self ~~ /<-[\x0..\xFF]>/
	    ?? utf16-encode(self)
            !! self ~ '';

	:$literal;
    }
}
