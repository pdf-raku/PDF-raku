use v6;
use Test;

plan 9;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Tools::Util :unbox;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = q:to"--END-OBJ--";
4 0 obj
<<
  /Type /Page
  /Parent 3 0 R
  /Resources << /Font << /F1 7 0 R >>/ProcSet 6 0 R >>
  /MediaBox [0 0 612 792]
  /Contents 5 0 R
>>
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Tools::IndObj.new-delegate( |%$ast);
isa_ok $ind-obj, ::('PDF::Tools::IndObj')::('Type::Page');
is $ind-obj.obj-num, 4, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
is_deeply $ind-obj.Type, (:name<Page>), '$.Type accessor';
is_deeply $ind-obj.Parent, (:ind-ref[3, 0]), '$.Parent accessor';
is_deeply $ind-obj.Resources, (:dict{ :Font( :dict{:F1( :ind-ref[7, 0] )} ), :ProcSet( :ind-ref[6, 0]) } ), '$.Resources accessor';
is_deeply $ind-obj.MediaBox, (:array[:int(0), :int(0), :int(612), :int(792)]), '$.MediaBox accessor';
is_deeply $ind-obj.Contents, (:ind-ref[5, 0]), '$.Contents accessor';
is_deeply $ind-obj.ast, $ast, 'ast regeneration';
