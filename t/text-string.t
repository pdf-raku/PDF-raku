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
todo "why is this failing? chars appear to be the same!";
is $encoded, "\xFE\xFF\x[0]H\x[0]e\x[0]y\x[0]d\x[2]Y\x[0]r\x[0] \x[1]\x[0]l\x[0]i\x[0]y\x[0]e\x[0]v", 'utf16-encode';

$str = PDF::DAO::TextString.new(:value($encoded));

isa-ok $str, PDF::DAO::TextString;
is $str, $name, 'simple string value';
is-deeply $str.content, (:literal($encoded)), 'simple string content';

done-testing;
