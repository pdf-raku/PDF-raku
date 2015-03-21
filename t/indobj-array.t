use v6;
use Test;

plan 7;

use PDF::Storage::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test :is-json-equiv;
use lib '.';
use t::Object :to-obj;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '42 5 obj [0.9505 1.0000 1.0890 [1 2 (abc)]] endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input );
my $object = $ind-obj.object;
isa_ok $object, Array;
is $ind-obj.obj-num, 42, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
my $content = $ind-obj.content;
isa_ok $content, Pair;
is-json-equiv $content, ( :array[:real(0.9505e0), :real(1e0), :real(1.089e0),
                             :array[:int(1), :int(2), :literal<abc>],
                     ]), '$.content';
is-json-equiv to-obj( $content ), [0.9505e0, 1e0, 1.089e0, [1, 2, "abc"]], '$.content to-obj';

is_deeply $ind-obj.ast, $ast, 'ast regeneration';
