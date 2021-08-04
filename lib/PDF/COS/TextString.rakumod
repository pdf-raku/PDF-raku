use v6;

use PDF::COS;

class PDF::COS::TextString
    does PDF::COS
    is Str {

    use PDF::COS::ByteString;

    has $.value;
    has Str $.type is rw = 'literal';
    has Bool $.bom is rw;

=begin pod

See [PDF 32000 TABLE 34 PDF data types]

text-string: Bytes that represent characters encoded using either
PDFDocEncoding or UTF-16BE with a leading byte-order marker

=end pod

    constant BOM-BE = "\xFE\xFF";

    our constant @pdfdoc-dec = ["", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "˘",
    "ˇ", "ˆ", "˙", "˝", "˛", "°", "˜", " ", "!", "\"", "", "\$", "\%",
    "\&", "'", "(", ")", "*", "+", ",", "-", ".", "/", "0", "1", "2",
    "3", "4", "5", "6", "7", "8", "9", ":", ";", "<", "=", ">", "?",
    "\@", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
    "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y",
    "Z", "[", "\\", "]", "^", "_", "`", "a", "b", "c", "d", "e", "f",
    "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s",
    "t", "u", "v", "w", "x", "y", "z", "\{", "|", "}", "~", "", "•",
    "†", "‡", "…", "—", "–", "ƒ", "⁄", "‹", "›", "−", "‰", "„", "“",
    "”", "‘", "’", "‚", "™", "ﬁ", "ﬂ", "Ł", "Œ", "Š", "Ÿ", "Ž", "ı",
    "ł", "œ", "š", "ž", "", "€", "¡", "¢", "£", "¤", "¥", "¦", "§",
    "¨", "©", "ª", "«", "¬", "", "®", "¯", "°", "±", "²", "³", "´",
    "μ", "¶", "·", "¸", "¹", "º", "»", "¼", "½", "¾", "¿", "À", "Á",
    "Â", "Ã", "Ä", "Å", "Æ", "Ç", "È", "É", "Ê", "Ë", "Ì", "Í", "Î",
    "Ï", "Ð", "Ñ", "Ò", "Ó", "Ô", "Õ", "Ö", "×", "Ø", "Ù", "Ú", "Û",
    "Ü", "Ý", "Þ", "ß", "à", "á", "â", "ã", "ä", "å", "æ", "ç", "è",
    "é", "ê", "ë", "ì", "í", "î", "ï", "ð", "ñ", "ò", "ó", "ô", "õ",
    "ö", "÷", "ø", "ù", "ú", "û", "ü", "ý", "þ", "ÿ"];

    constant %pdfdoc-enc = do {
        my Str %enc{UInt};
        for 0 .. 255 {
            my $ch := @pdfdoc-dec[$_];
            %enc{$ch.ord} = .chr if $ch;
        }
        %enc;
    }

    method new( Str :$value! is copy, :$bom is copy, |c ) {
        if $value ~~ PDF::COS::ByteString {
            # decode UTF-18BE / PDFDoc encoded byte string
	    my uint8 @be = $value.ords;
            if $value.starts-with(BOM-BE) {
                $value = Blob.new(@be).decode('utf-16');
                $bom //= True;
            }
            else {
                $value = @be.map({@pdfdoc-dec[$_] // ''}).join;
                $bom //= False;
            }
        }
        my \obj = callwith(:$value, |c); # dispatch to Str.new
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

    our sub pdfdoc-encode(Str $str --> Str) {
        $str.ords.map({%pdfdoc-enc{$_} // ''}).join;
    }

    method content {
        my $val = self.bom // self ~~ /<-[\x0..\xFF]>/
	    ?? utf16-encode(self)
            !! pdfdoc-encode(self);

	$!type => $val;
    }
    multi method COERCE(Str:D $value, |c) is default {
        $?CLASS.new: :$value, |c;
    }
}
