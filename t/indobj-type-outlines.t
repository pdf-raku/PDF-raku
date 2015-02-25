use v6;
use Test;

plan 8;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Tools::Util :unbox;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = q:to"--END-OBJ--";
18 0 obj
<< /Count 3 /First 19 0 R /Last 20 0 R /Type /Outlines >>
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Tools::IndObj.new-delegate( |%$ast);
isa_ok $ind-obj, ::('PDF::Tools::IndObj')::('Type::Outlines');
is $ind-obj.obj-num, 18, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
is_deeply $ind-obj.Type, (:name<Outlines>), '$.Type accessor';
is_deeply $ind-obj.Count, (:int(3)), '$.Count accessor';
is_deeply $ind-obj.First, (:ind-ref[19, 0]), '$.First accessor';
is_deeply $ind-obj.Last, (:ind-ref[20, 0]), '$.Last accessor';
is_deeply $ind-obj.ast, $ast, 'ast regeneration';
