use v6;
use Test;
plan 7;

use PDF::COS;
use PDF::COS::TextString;

my PDF::COS::TextString $str .= new(:value<Writer>);

isa-ok $str, PDF::COS::TextString;
is $str, "Writer", 'simple string value';
is-deeply $str.content, (:literal<Writer>), 'simple string content';

my $name = "Heydər Əliyev";
my $encoded = PDF::COS::TextString::utf16-encode($name);
my $literal = [~] "\xFE\xFF", "\x[0]H", "\x[0]e", "\x[0]y", "\x[0]d", "\x[2]Y", "\x[0]r", "\x[0] ",
   "\x[1]\x[8f]", "\x[0]l", "\x[0]i", "\x[0]y", "\x[0]e", "\x[0]v";
is $encoded, $literal, 'utf16-encode';

$str .= new(:value($encoded));

isa-ok $str, PDF::COS::TextString;
is $str, $name, 'simple string value';
is-deeply $str.content, (:$literal), 'simple string content';

done-testing;
