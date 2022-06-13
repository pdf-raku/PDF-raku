use v6;
use Test;
plan 10;

use PDF::COS;
use PDF::COS::ByteString;
use PDF::COS::TextString;

my PDF::COS::TextString $str .= new(:value<Writer>);

isa-ok $str, PDF::COS::TextString;
is $str, "Writer", 'simple string value';
is-deeply $str.content, (:literal<Writer>), 'simple string content';

# UTF16 encoding
my $name = "Heydər Əliyev";
my PDF::COS::ByteString() $encoded = PDF::COS::TextString::utf16-encode($name);
my $literal = [~] "\xFE\xFF", "\x[0]H", "\x[0]e", "\x[0]y", "\x[0]d", "\x[2]Y", "\x[0]r", "\x[0] ",
   "\x[1]\x[8f]", "\x[0]l", "\x[0]i", "\x[0]y", "\x[0]e", "\x[0]v";
is $encoded, $literal, 'utf16-encode';

$str .= new(:value($encoded));

isa-ok $str, PDF::COS::TextString;
is $str, $name, 'simple string value';
is-deeply $str.content.value, $literal, 'utf-8 string content';

# PDFDoc encoding
$encoded = "Registrant\x[90]s\n";
$str .= new(:value($encoded));
is $str, "Registrant’s\n", "pdfdoc encoded value";
is $str.content.value, $encoded, 'pdfdoc encoded content';

$str.bom = True;
is-deeply $str.content, (:literal("þÿ\0R\0e\0g\0i\0s\0t\0r\0a\0n\0t \x[19]\0s\0\n")), 'utf8 encoded content';

done-testing;
