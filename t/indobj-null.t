use v6;
use Test;

plan 7;

use PDF::Storage::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use lib '.';
use t::Object :to-obj;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '42 5 obj null endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input );
isa_ok $ind-obj.object, ::('PDF::Object')::('Null');
is $ind-obj.obj-num, 42, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
my $content = $ind-obj.content;
isa_ok $content, Pair;
is_deeply to-obj( $content ), Any, '$.content to-obj';
is_deeply $content, (:null(Any)), '$.content';

is_deeply $ind-obj.ast, $ast, 'ast regeneration';
