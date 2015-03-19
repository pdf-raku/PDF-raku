use v6;
use Test;

plan 7;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use lib '.';
use t::Object :to-obj;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '42 5 obj true endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Tools::IndObj.new( |%$ast, :$input );
is $ind-obj.obj-num, 42, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
isa_ok $ind-obj.object, Bool;
my $content = $ind-obj.content;
isa_ok $content, Pair;
is_deeply to-obj( $content ), True, '$.content to-obj';
is_deeply $content, (:bool), '$.content';

is_deeply $ind-obj.ast, $ast, 'ast regeneration';
