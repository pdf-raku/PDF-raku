use v6;
use Test;

plan 9;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Tools::Util :unbox;

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
my $ind-obj = PDF::Tools::IndObj.new-delegate( |%$ast);
isa_ok $ind-obj, ::('PDF::Tools::IndObj')::('Type::Font::Type1');
is $ind-obj.obj-num, 7, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
is_deeply $ind-obj.Type, (:name<Font>), '$.Type accessor';
is_deeply $ind-obj.Subtype, (:name<Type1>), '$.Subype accessor';
is_deeply $ind-obj.Name, (:name<F1>), '$.Name accessor';
is_deeply $ind-obj.BaseFont, (:name<Helvetica>), '$.BaseFont accessor';
is_deeply $ind-obj.Encoding, (:name<MacRomanEncoding>), '$.Encoding accessor';
is_deeply $ind-obj.ast, $ast, 'ast regeneration';
