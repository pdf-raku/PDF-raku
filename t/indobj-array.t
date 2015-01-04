use v6;
use Test;

plan 6;

use PDF::Basic::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Basic;
use PDF::Basic::Util :unbox;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '42 5 obj [0.9505 1.0000 1.0890 [1 2 (abc)]] endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Basic::IndObj.new-delegate( |%$ast, :$input );
isa_ok $ind-obj, ::('PDF::Basic::IndObj')::('Array');
is $ind-obj.obj-num, 42, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
my $content = $ind-obj.content;
isa_ok $content, Hash;
is_deeply unbox( |%$content ), [0.9505e0, 1e0, 1.089e0, [1, 2, "abc"]], '$.content';

is_deeply $ind-obj.ast, $ast, 'ast regeneration';
