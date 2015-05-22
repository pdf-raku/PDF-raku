use v6;
use Test;

plan 9;

use PDF::Storage::IndObj;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

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
my $ind-obj = PDF::Storage::IndObj.new( |%$ast);
is $ind-obj.obj-num, 4, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $page-obj = $ind-obj.object;
isa-ok $page-obj, ::('PDF::Object')::('Type::Page');
is $page-obj.Type, 'Page', '$.Type accessor';
is $page-obj.Parent, (:ind-ref[3, 0]), '$.Parent accessor';
is $page-obj.Resources, { :Font{ :F1( :ind-ref[7, 0] )}, :ProcSet( :ind-ref[6, 0]) }, '$.Resources accessor';
is-json-equiv $page-obj.MediaBox, [0, 0, 612, 792], '$.MediaBox accessor';
is-deeply $page-obj.Contents, (:ind-ref[5, 0]), '$.Contents accessor';
is-deeply $ind-obj.ast, $ast, 'ast regeneration';
