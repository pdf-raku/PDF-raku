use v6;
use Test;

plan 18;

use PDF::Storage::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test :is-json-equiv;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '37 5 obj 42 endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input );
isa-ok $ind-obj.object, Int;
does-ok $ind-obj.object, ::('PDF::Object::Int');
is $ind-obj.obj-num, 37, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
isa-ok $ind-obj.object, Int, '$.object';
is $ind-obj.object, 42, '$.object';
my $content = $ind-obj.content;
isa-ok $content, Pair;
is-json-equiv $content, (:int(42)), '$.content';

is-json-equiv $ind-obj.ast, $ast, 'ast regeneration';

$input = '5 6 obj 4.2 endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
$ast = $/.ast;
$ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input );
isa-ok $ind-obj.object, Rat;
does-ok $ind-obj.object, ::('PDF::Object::Real');
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 6, '$.gen-num';
isa-ok $ind-obj.object, Rat, '$.object';
is $ind-obj.object, 4.2, '$.object';
$content = $ind-obj.content;
isa-ok $content, Pair;
is-json-equiv $content, (:real(4.2)), '$.content';
is-json-equiv $ind-obj.ast, $ast, 'ast regeneration';

