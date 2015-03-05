use v6;
use Test;

plan 7;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Object :unbox;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = q:to"--END-OBJ--";
3 0 obj
<<
  /Type /Pages
  /Count 1
  /Kids [4 0 R]
>>
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Tools::IndObj.new( |%$ast);
is $ind-obj.obj-num, 3, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $pages-obj = $ind-obj.object;
isa_ok $pages-obj, ::('PDF::Object')::('Type::Pages');
is $pages-obj.Type, 'Pages', '$.Type accessor';
is $pages-obj.Count, 1, '$.Count accessor';
is_deeply $pages-obj.Kids, [ :ind-ref[4, 0] ], '$.Kids accessor';
is_deeply $ind-obj.ast, $ast, 'ast regeneration';
