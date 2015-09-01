use v6;
use Test;

plan 13;

use PDF::Storage::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test :is-json-equiv;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '42 5 obj (a literal string) endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input );
isa-ok $ind-obj.object, Str;
is $ind-obj.obj-num, 42, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
is $ind-obj.object, 'a literal string', '$.object';
my $content = $ind-obj.content;
isa-ok $content, Pair;
is-deeply $content, (:literal("a literal string")), '$.content';

$input = '123 4 obj <736E6F6f7079> endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
$ast = $/.ast;
$ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input );
isa-ok $ind-obj.object, Str;
is $ind-obj.obj-num, 123, '$.obj-num';
is $ind-obj.gen-num, 4, '$.gen-num';
is $ind-obj.object, 'snoopy', '$.object';
$content = $ind-obj.content;
isa-ok $content, Pair;
is-json-equiv $content, (:hex-string<snoopy>), '$.content';

is-json-equiv $ind-obj.ast, $ast, 'ast regeneration';
