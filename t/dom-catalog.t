use v6;
use Test;

plan 7;

use PDF::Storage::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = q:to"--END-OBJ--";
215 0 obj
<< /Lang (EN-US) /LastModified (D:20081012130709)
   /MarkInfo << /LetterspaceFlags 0 /Marked true >> /Metadata 10 0 R
   /Outlines 18 0 R /PageLabels 210 0 R /PageLayout /OneColumn /Pages 212 0 R
   /PieceInfo << /MarkedPDF << /LastModified (D:20081012130709) >> >>
   /StructTreeRoot 25 0 R
   /Type /Catalog
>>
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast);
is $ind-obj.obj-num, 215, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $object = $ind-obj.object;
isa-ok $object, ::('PDF::DOM')::('Catalog');
is $object<PageLayout>, 'OneColumn', 'dict lookup';
is-deeply $object.Pages, (:ind-ref[212, 0]), '$.Pages accessor';
is-deeply $object.Outlines, (:ind-ref[18, 0]), '$.Outlines accessor';
is-deeply $ind-obj.ast, $ast, 'ast regeneration';
