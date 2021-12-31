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

See - [PDF 32000 TABLE 34 PDF data types]
    - [IS0-32000 Table D.2 – PDFDocEncoding Character Set]

text-string: Bytes that represent characters encoded using either
PDFDocEncoding or UTF-16BE with a leading byte-order marker

To regenerate:

    =begin code :lang<raku>
    use JSON::Fast;

    my $tab = from-json("PDF-ISO_32000-raku/resources/ISO_32000/misc/Table_D2-PDFDocEncoding_Character_Set.json".IO.slurp)
    my $rows = $tab<table><rows>;

    my @enc = '' xx 256;

    for $rows.List {
        my $u = .[4];
        if $u.starts-with('U+') {
            my $i = .[1].Int;
            @enc[$i] = :16($u.substr(2)).chr;
        }
    }

    say @enc.raku;
    =end code

=end pod

    constant BOM-BE = "\xFE\xFF";

    our constant @pdfdoc-dec = [
     "\0", "\x[1]", "\x[2]", "\x[3]", "\x[4]", "\x[5]", "\x[6]",
     "\x[7]", "\b", "\t", "\n", "\x[B]", "\x[C]", "\r", "\x[E]",
     "\x[F]", "\x[10]", "\x[11]", "\x[12]", "\x[13]", "\x[14]",
     "\x[15]", "\x[17]", "\x[17]", "˘", "ˇ", "ˆ", "˙", "˝", "˛", "˚",
     "˜", " ", "!", "\"", "#", "\$", "\%", "\&", "'", "(", ")", "*",
     "+", ",", "-", ".", "/", "0", "1", "2", "3", "4", "5", "6", "7",
     "8", "9", ":", ";", "<", "=", ">", "?", "\@", "A", "B", "C", "D",
     "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q",
     "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "[", "\\", "]", "^",
     "_", "`", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k",
     "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x",
     "y", "z", "\{", "|", "}", "~", '', "•", "†", "‡", "…", "—", "–",
     "ƒ", "⁄", "‹", "›", "−", "‰", "„", "“", "”", "‘", "’", "‚", "™",
     "ﬁ", "ﬂ", "Ł", "Œ", "Š", "Ÿ", "Ž", "ı", "ł", "œ", "š", "ž", '',
     "€", "¡", "¢", "£", "¤", "¥", "¦", "§", "¨", "©", "ª", "«", "¬",
     '', "®", "¯", "°", "±", "²", "³", "´", "µ", "¶", "·", "¸", "¹",
     "º", "»", "¼", "½", "¾", "¿", "À", "Á", "Â", "Ã", "Ä", "Å", "Æ",
     "Ç", "È", "É", "Ê", "Ë", "Ì", "Í", "Î", "Ï", "Ð", "Ñ", "Ò", "Ó",
     "Ô", "Õ", "Ö", "×", "Ø", "Ù", "Ú", "Û", "Ü", "Ý", "Þ", "ß", "à",
     "á", "â", "ã", "ä", "å", "æ", "ç", "è", "é", "ê", "ë", "ì", "í",
     "î", "ï", "ð", "ñ", "ò", "ó", "ô", "õ", "ö", "÷", "ø", "ù", "ú",
     "û", "ü", "ý", "þ", "ÿ"];

    constant %pdfdoc-enc = do {
        my Str %enc{UInt};
        for 0 .. 255 {
            my $ch := @pdfdoc-dec[$_];
            %enc{$ch.ord} = .chr if $ch;
        }
        %enc;
    }

    method new( Str:D :$value! is copy, Bool :$bom is copy, |c ) {
        given $value {
            when PDF::COS::TextString {
                return $_;
            }
            when .starts-with(BOM-BE) {
                $bom //= True;
                $value = .substr(2).encode('latin-1').decode('utf16be');
            }
            when PDF::COS::ByteString {
                # decode UTF-16BE / PDFDoc encoded byte string
                $bom //= False;
                $value = .ords.map({@pdfdoc-dec[$_] // ''}).join;
            }
        }

        callwith(:$value, :$bom, |c); # dispatch to Str.new
    }

    our sub utf16-encode(Str $str --> Str) {
	 BOM-BE ~ $str.encode('utf16be').decode('latin-1');
    }

    our sub pdfdoc-encode(Str $str --> Str) {
        $str.ords.map({%pdfdoc-enc{$_} // return Nil}).join;
    }

    method content {
        my $doc-enc = pdfdoc-encode(self)
            unless $!bom;
	$!type => $doc-enc // utf16-encode(self);
    }
    multi method COERCE(Str:D $value, |c) {
        self.new: :$value, |c;
    }
}
