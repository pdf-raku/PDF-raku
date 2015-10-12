use v6;
use Test;

plan 7;

use PDF::Storage::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '42 5 obj null endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input );
isa-ok $ind-obj.object, ::('PDF::DAO')::('Null');
is $ind-obj.obj-num, 42, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
ok ! $ind-obj.object.defined, '$.object';
my $content = $ind-obj.content;
isa-ok $content, Pair;
is-deeply $content, (:null(Any)), '$.content';

is-deeply $ind-obj.ast, $ast, 'ast regeneration';
