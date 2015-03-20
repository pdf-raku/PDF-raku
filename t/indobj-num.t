use v6;
use Test;

plan 16;

use PDF::Storage::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use lib '.';
use t::Object :to-obj;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '37 5 obj 42 endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input );
isa_ok $ind-obj.object, Int;
is $ind-obj.obj-num, 37, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
my $content = $ind-obj.content;
isa_ok $content, Pair;
isa_ok to-obj( $content ), Int, '$.content to-obj';
is to-obj( $content ), 42, '$.content to-obj';
is_deeply $content, (:int(42)), '$.content';

is_deeply $ind-obj.ast, $ast, 'ast regeneration';

$input = '5 6 obj 4.2 endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
$ast = $/.ast;
$ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input );
isa_ok $ind-obj.object, Rat;
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 6, '$.gen-num';
$content = $ind-obj.content;
isa_ok $content, Pair;
isa_ok to-obj( $content ), Rat, '$.content to-obj';
is to-obj( $content ), 4.2, '$.content to-obj';
is_deeply $content, (:real(4.2)), '$.content';

is_deeply $ind-obj.ast, $ast, 'ast regeneration';

