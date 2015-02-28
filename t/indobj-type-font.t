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
my $ind-obj = PDF::Tools::IndObj.new( |%$ast);
my $object = $ind-obj.object;
is $ind-obj.obj-num, 7, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
isa_ok $object, ::('PDF::Object')::('Type::Font::Type1');
is_deeply $object.Type, (:name<Font>), '$.Type accessor';
is_deeply $object.Subtype, (:name<Type1>), '$.Subype accessor';
is_deeply $object.Name, (:name<F1>), '$.Name accessor';
is_deeply $object.BaseFont, (:name<Helvetica>), '$.BaseFont accessor';
is_deeply $object.Encoding, (:name<MacRomanEncoding>), '$.Encoding accessor';
is_deeply $ind-obj.ast, $ast, 'ast regeneration';
