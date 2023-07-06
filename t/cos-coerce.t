use Test;
plan 47;

use PDF::Grammar::Test :&is-json-equiv;
use PDF::COS::Bool;
use PDF::COS::Name;
use PDF::COS::ByteString;
use PDF::COS::DateString;
use PDF::COS::TextString;
use PDF::COS::Int;
use PDF::COS::Null;
use PDF::COS::Real;
use PDF::COS::Type::Info;
use PDF::COS::Dict;
use PDF::COS::Stream;

my PDF::COS::ByteString() $string = "Test\n";
is $string, "Test\n";
does-ok $string, PDF::COS::ByteString;
is-deeply $string.content, (:literal("Test\n"));

lives-ok {$string = "abc"}, 'byte-string coercement latin chars';
quietly dies-ok {$string = "\x[abc]"}, 'byte-string coercement non-latin chars';

my PDF::COS::Name() $name = 'Fred';
is $name, 'Fred';
does-ok $name, PDF::COS::Name;
is-deeply $name.content, (:name<Fred>);
lives-ok {$name = "abc\x[abc]"}, 'name coercement non-latin chars';
is-deeply $name.content, (:name("abc\x[abc]"));

my PDF::COS::TextString() $text = 'Hello';
is $text, 'Hello';
does-ok $text, PDF::COS::TextString;
is-deeply $text.content, (:literal<Hello>);

my $date-string = "D:20151225000000Z00'00'";
for $date-string, DateTime.new( :year(2015), :month(12), :day(25) ) -> $date-in {
    my PDF::COS::DateString() $date = $date-in;
    is $date, $date-string;
    does-ok $date, PDF::COS::DateString;
    is-deeply $date.content, (:literal($date-string));
}

my PDF::COS::Int() $int = 42;
is $int, 42;
does-ok $int, PDF::COS::Int;
is-deeply $int.content, 42;
lives-ok {$int = 99};
dies-ok {$int = "oops"};

my PDF::COS::Real() $real = 4.2;
is $real, 4.2;
does-ok $real, PDF::COS::Real;
is-deeply $real.content, 4.2;

my PDF::COS::Null() $null = Any;
nok $null.defined;
isa-ok $null, PDF::COS::Null;
is-deeply $null.content, (:null(Any));

my PDF::COS::Bool() $bool = True;
is-json-equiv $bool, True;
does-ok $bool, PDF::COS::Bool;
is-json-equiv $bool.content, (:bool);

$bool = False;
is-json-equiv $bool.so, False;
does-ok $bool, PDF::COS::Bool;
is-json-equiv $bool.content, (:!bool);

my PDF::COS::Type::Info() $info = %(:Title("You better work"));
isa-ok $info, "PDF::COS::Dict";
does-ok $info,  PDF::COS::Type::Info;
is $info.Title, "You better work";
does-ok $info.Title, PDF::COS::TextString;

my $decoded = "BT /F1 24 Tf  15 25 Td (Hello, world!) Tj ET";
my $Length = $decoded.chars;

my PDF::COS::Dict() $dict = { :$Length };
is $dict<Length>, $Length;

my %stream = %( :dict{ :$Length }, :$decoded );

my PDF::COS::Stream() $contents = %stream;
is $contents.decoded, $decoded;
is $contents.Length, $Length;

$contents = PDF::COS.coerce: :%stream;
is $contents.decoded, $decoded;
is $contents.Length, $Length;

sub coerce-dict-test(PDF::COS::Dict() $dict) {
    isa-ok($dict, PDF::COS::Dict);
    is $dict<Length>, $Length;
}

coerce-dict-test( { :$Length});
