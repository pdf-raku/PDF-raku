use v6;
use Test;

plan 14;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Tools::Util :unbox;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '37 5 obj 42 endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Tools::IndObj.new( |%$ast, :$input );
isa_ok $ind-obj.object, ::('PDF::Object')::('Num');
is $ind-obj.obj-num, 37, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
my $content = $ind-obj.content;
isa_ok $content, Pair;
is_deeply unbox( $content ), 42, '$.content unboxed';
is_deeply $content, (:int(42)), '$.content';

is_deeply $ind-obj.ast, $ast, 'ast regeneration';


$input = '5 6 obj 4.2 endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
$ast = $/.ast;
$ind-obj = PDF::Tools::IndObj.new( |%$ast, :$input );
isa_ok $ind-obj.object, ::('PDF::Object')::('Num');
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 6, '$.gen-num';
$content = $ind-obj.content;
isa_ok $content, Pair;
is_deeply unbox( $content ), 4.2e0, '$.content unboxed';
is_deeply $content, (:real(4.2e0)), '$.content';

is_deeply $ind-obj.ast, $ast, 'ast regeneration';

