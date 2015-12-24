use v6;
use Test;
use PDF::DAO;
use PDF::DAO::TextString;

my $str = PDF::DAO::TextString.new(:value<Writer>);

isa-ok $str, PDF::DAO::TextString;
is $str, "Writer", 'simple string value';
is-deeply $str.content, (:literal<Writer>), 'simple string content';

my $name = "Heydər Əliyev";
my $encoded = PDF::DAO::TextString::utf16-encode($name);
my $expected = [~] "\xFE\xFF", "\x[0]H", "\x[0]e", "\x[0]y", "\x[0]d", "\x[2]Y", "\x[0]r", "\x[0] ",
   "\x[1]\x[8f]", "\x[0]l", "\x[0]i", "\x[0]y", "\x[0]e", "\x[0]v";
is $encoded, $expected, 'utf16-encode';

$str = PDF::DAO::TextString.new(:value($encoded));

isa-ok $str, PDF::DAO::TextString;
is $str, $name, 'simple string value';
is-deeply $str.content, (:literal($expected)), 'simple string content';

done-testing;
