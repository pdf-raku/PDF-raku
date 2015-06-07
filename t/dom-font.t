use v6;
use Test;

plan 9;

use PDF::Storage::IndObj;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = q:to"--END-OBJ--";
7 0 obj
<<
/Type /Font
/Subtype /Type1
/Name /F1
/BaseFont /Helvetica
/Encoding /MacRomanEncoding
>>
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast);
my $object = $ind-obj.object;
is $ind-obj.obj-num, 7, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
isa-ok $object, ::('PDF::DOM')::('Font::Type1');
is $object.Type, 'Font', '$.Type accessor';
is $object.Subtype, 'Type1', '$.Subype accessor';
is $object.Name, 'F1', '$.Name accessor';
is $object.BaseFont, 'Helvetica', '$.BaseFont accessor';
is $object.Encoding, 'MacRomanEncoding', '$.Encoding accessor';
is-json-equiv $ind-obj.ast, $ast, 'ast regeneration';
