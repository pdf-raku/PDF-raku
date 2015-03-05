use v6;
use Test;

plan 8;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Object :unbox;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = q:to"--END-OBJ--";
18 0 obj
<< /Count 3 /First 19 0 R /Last 20 0 R /Type /Outlines >>
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Tools::IndObj.new( |%$ast);
is $ind-obj.obj-num, 18, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $outlines-obj = $ind-obj.object;
isa_ok $outlines-obj, ::('PDF::Object')::('Type::Outlines');
is $outlines-obj.Type, 'Outlines', '$.Type accessor';
is $outlines-obj.Count, 3, '$.Count accessor';
is_deeply $outlines-obj.First, (:ind-ref[19, 0]), '$.First accessor';
is_deeply $outlines-obj.Last, (:ind-ref[20, 0]), '$.Last accessor';
is_deeply $ind-obj.ast, $ast, 'ast regeneration';
