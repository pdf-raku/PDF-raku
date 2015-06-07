use v6;
use Test;

plan 16;

use PDF::Storage::IndObj;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = q:to"--END-OBJ--";
6 0 obj% Form XObject
<< /Type /XObject
/Subtype /Form
/FormType 1
/BBox [ 0 0 1000 1000 ]
/Matrix [ 1 0 0 1 0 0 ]
/Resources << /ProcSet [ /PDF ] >>
/Length 58
>>
stream
0 0 m
0 1000 l
1000 1000 l
1000 0 l
f
endstream
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input);
is $ind-obj.obj-num, 6, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $xform-obj = $ind-obj.object;
isa-ok $xform-obj, ::('PDF::DOM')::('XObject::Form');
is $xform-obj.Type, 'XObject', '$.Type accessor';
is $xform-obj.Subtype, 'Form', '$.Subtype accessor';
is-json-equiv $xform-obj.Resources, { :ProcSet( [ <PDF> ] ) }, '$.Resources accessor';
is-json-equiv $xform-obj.BBox, [ 0, 0, 1000, 1000 ], '$.MediaBox accessor';
is $xform-obj.encoded, "0 0 m\n0 1000 l\n1000 1000 l\n1000 0 l\nf", '$.encoded accessor';

$input = q:to"--END-OBJ--";
14 0 obj
<<
/Intent/RelativeColorimetric
/Type/XObject
/ColorSpace/DeviceGray
/Subtype/Image
/Name/X
/Width 2988
/BitsPerComponent 8
/Length 13
/Height 2286
/Filter/DCTDecode
>>
stream
(binary data)
endstream
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
$ast = $/.ast;
$ind-obj = PDF::Storage::IndObj.new( |%$ast, :$input);
is $ind-obj.obj-num, 14, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $ximage-obj = $ind-obj.object;
isa-ok $ximage-obj, ::('PDF::DOM')::('XObject::Image');
is $ximage-obj.Type, 'XObject', '$.Type accessor';
is $ximage-obj.Subtype, 'Image', '$.Subtype accessor';
is-json-equiv $ximage-obj.ColorSpace, 'DeviceGray', '$.ColorSpace accessor';
is-json-equiv $ximage-obj.BitsPerComponent, 8, '$.BitsPerComponent accessor';
is $ximage-obj.encoded, "(binary data)", '$.encoded accessor';
