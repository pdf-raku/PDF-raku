use v6;

use PDF::DAO;

class PDF::DAO::TextString
    does PDF::DAO
    is Str {

    has Str $.type is rw = 'literal';
    has Bool $.bom;

=begin pod

See [PDF 1.7 TABLE 34 PDF data types]

text-string: Bytes that represent characters encoded using either
PDFDocEncoding or UTF-16BE with a leading byte-order marker

=end pod

    method new( Str :$value! is copy, Bool :$bom is copy = False, |c ) {
        if $value ~~ /^ $<bom>=[\xFE \xFF]/ {
	    my @be = $value.ords;
            $value = Buf.new(@be).decode('utf-16');
        }
        nextwith( :$value, :$bom, |c );
    }

    our sub utf16-encode(Str $str --> Str) {
         constant BOM-BE = "\xFE\xFF";
	 my Str $byte-string = $str.encode("utf-16").map( -> $ord {
                   my $lo = $ord mod 0x100;
                   my $hi = $ord div 0x100;
		   $hi.chr ~ $lo.chr;
	 }).join('');

	 BOM-BE ~ $byte-string;
    }

    method content {
        my $val = self.bom || self ~~ /<-[\x0..\xFF]>/
	    ?? utf16-encode(self)
            !! self ~ '';

	$.type => $val;
    }
}
