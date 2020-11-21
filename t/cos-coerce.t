use Test;
plan 43;

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

my PDF::COS::ByteString $string .= COERCE('Test');
is $string, 'Test';
does-ok $string, PDF::COS::ByteString;
is-deeply $string.content, (:literal<Test>);

my PDF::COS::Name $name .= COERCE('Fred');
is $name, 'Fred';
does-ok $name, PDF::COS::Name;
is-deeply $name.content, (:name<Fred>);

my PDF::COS::TextString $text .= COERCE('Hello');
is $text, 'Hello';
does-ok $text, PDF::COS::TextString;
is-deeply $text.content, (:literal<Hello>);

my $date-string = "D:20151225000000Z00'00'";
for $date-string, DateTime.new( :year(2015), :month(12), :day(25) ) -> $date-in {
    my PDF::COS::DateString $date .= COERCE($date-in);
    is $date, $date-string;
    does-ok $date, PDF::COS::DateString;
    is-deeply $date.content, (:literal($date-string));
}

my PDF::COS::Int $int .= COERCE(42);
is $int, 42;
does-ok $int, PDF::COS::Int;
is-deeply $int.content, (:int(42));

my PDF::COS::Real $real .= COERCE(4.2);
is $real, 4.2;
does-ok $real, PDF::COS::Real;
is-deeply $real.content, (:real(4.2));

my PDF::COS::Null $null .= COERCE(Any);
nok $null.defined;
isa-ok $null, PDF::COS::Null;
is-deeply $null.content, (:null(Any));

my PDF::COS::Bool $bool .= COERCE(True);
is-json-equiv $bool, True;
does-ok $bool, PDF::COS::Bool;
is-json-equiv $bool.content, (:bool);

$bool .= COERCE(False);
is-json-equiv $bool.so, False;
does-ok $bool, PDF::COS::Bool;
is-json-equiv $bool.content, (:!bool);

my PDF::COS::Type::Info $info .= COERCE: %(:Title("You better work"));
isa-ok $info, "PDF::COS::Dict";
does-ok $info,  PDF::COS::Type::Info;
is $info.Title, "You better work";
does-ok $info.Title, PDF::COS::TextString;
#
lives-ok {$int .= COERCE: 99};
dies-ok {$int .= COERCE: "oops"};

my $decoded = "BT /F1 24 Tf  15 25 Td (Hello, world!) Tj ET";
my $Length = $decoded.chars;

my PDF::COS::Dict $dict .= COERCE: { :$Length};
is $dict<Length>, $Length;

my %stream = %( :dict{ :$Length }, :$decoded );

my PDF::COS::Stream $contents .= COERCE: %stream;
is $contents.decoded, $decoded;
is $contents.Length, $Length;

$contents = PDF::COS.coerce: :%stream;
is $contents.decoded, $decoded;
is $contents.Length, $Length;

sub coerce-dict-test(PDF::COS::Dict() $dict) {
    isa-ok($dict, PDF::COS::Dict);
    is $dict<Length>, $Length;
}

if $*PERL.compiler.version > v2020.10 {
    coerce-dict-test( { :$Length});
}
else {
    skip "Rakudo 2020.11 needed for coercements", 2;
}
