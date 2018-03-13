use v6;

use PDF::COS;

class PDF::COS::TextString
    does PDF::COS
    is Str {

    has $.value;
    has Str $.type is rw = 'literal';
    has Bool $.bom is rw;

=begin pod

See [PDF 1.7 TABLE 34 PDF data types]

text-string: Bytes that represent characters encoded using either
PDFDocEncoding or UTF-16BE with a leading byte-order marker

=end pod

    constant BOM-BE = "\xFE\xFF";

    method new( Str :$value! is copy, :$bom is copy, |c ) {
        if $value.starts-with(BOM-BE) {
	    my uint8 @be = $value.ords;
            $value =  Buf.new(@be).decode('utf-16');
            $bom //= True;
        }
        my \obj = nextwith(:$value, |c); # dispatch to Str.new
        obj.bom = $_ with $bom;
        obj;
    }

    our sub utf16-encode(Str $str --> Str) {
	 my Str \byte-string = $str.encode("utf-16").map( -> \ord {
                   my \lo = ord mod 0x100;
                   my \hi = ord div 0x100;
		   hi.chr ~ lo.chr;
	 }).join('');

	 BOM-BE ~ byte-string;
    }

    method content {
        my $val = self.bom || self ~~ /<-[\x0..\xFF]>/
	    ?? utf16-encode(self)
            !! self ~ '';

	$.type => $val;
    }
}
