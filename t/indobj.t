use v6;
use Test;

plan 41;

use PDF::Storage::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use lib '.';
use t::Object :to-obj;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-ObjStm-Flate.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed: $input";
my $ast = $/.ast;

my $ind-obj = PDF::Storage::IndObj.new( :$input, |%( $ast.kv ) );
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $object = $ind-obj.object;
isa-ok $object, ::('PDF::Object::Stream');
isa-ok $object, Hash;
isa-ok $object.Length, Int, '$.Length';
is $object.Length, 167, '$.Length';
is $object.Type, 'ObjStm', '$.Type';

# crosschecks on /Type
require ::('PDF::Object::Type::Catalog');
my $dict = { :Outlines(:ind-ref[2, 0]), :Type<Catalog> };
my $catalog-obj = ::('PDF::Object::Type::Catalog').new( :$dict );
isa-ok $catalog-obj, ::('PDF::Object::Type::Catalog');
isa-ok $catalog-obj.Type, Str, 'catalog $.Type';
is $catalog-obj.Type, 'Catalog', 'catalog $.Type';

$dict<Type>:delete;
lives-ok {$catalog-obj = ::('PDF::Object::Type::Catalog').new( :$dict )}, 'catalog .new with valid /Type - lives';
isa-ok $catalog-obj.Type, Str, 'catalog $.Type';
is $catalog-obj.Type, 'Catalog', 'catalog $.Type';

$dict<Type> = :name<Wtf>;
dies-ok {::('PDF::Object::Type::Catalog').new( :$dict )}, 'catalog .new with invalid /Type - dies';

$input = q:to"--END--";
16 0 obj
<< /Type /Font /Subtype /TrueType
   /BaseFont /CourierNewPSMT
   /Encoding /WinAnsiEncoding
   /FirstChar 111
    /FontDescriptor 15 0 R
   /LastChar 111
   /Widths [ 600 ] >>
endobj
--END--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed: $input";
$ast = $/.ast;

# misc types follow

$ind-obj = PDF::Storage::IndObj.new( :$input, |%( $ast.kv ) );
my $tt-font-obj = $ind-obj.object;
isa-ok $tt-font-obj, ::('PDF::Object::Type::Font::TrueType');
is $tt-font-obj.Type, 'Font', 'tt font $.Type';
is $tt-font-obj.Subtype, 'TrueType', 'tt font $.Subype';
is $tt-font-obj.Encoding, 'WinAnsiEncoding', 'tt font $.Encoding';

require ::('PDF::Object::Type::Font::Type0');
$dict = to-obj :dict{ :BasedFont(:name<Wingdings-Regular>), :Encoding(:name<Identity-H>) };
my $t0-font-obj = ::('PDF::Object::Type::Font::Type0').new( :$dict );
is $t0-font-obj.Type, 'Font', 't0 font $.Type';
is $t0-font-obj.Subtype, 'Type0', 't0 font $.Subype';
is $t0-font-obj.Encoding, 'Identity-H', 't0 font $.Encoding';

use PDF::Object::Type::Font::Type1;
class SubclassedType1Font is PDF::Object::Type::Font::Type1 {};
my $sc-font-obj = SubclassedType1Font.new;
is $sc-font-obj.Type, 'Font', 'sc font $.Type';
is $sc-font-obj.Subtype, 'Type1', 'sc font $.Subype';

use PDF::Object::Real;
my $num-obj = PDF::Object.compose( :real(4.2) );
is-deeply $num-obj.content, (:real(4.2)), 'composed object $.content';
is +$num-obj, 4.2, 'composed object Num coercement';
is-deeply ~$num-obj, '4.2', 'composed object Str coercement';
is-deeply ?$num-obj, True, 'composed object Bool coercement';

my $ind-obj2 = PDF::Storage::IndObj.new( :object($num-obj), :obj-num(4), :gen-num(2) );
is-deeply $ind-obj2.object, $num-obj, ':object constructor';
is-deeply $ind-obj2.obj-num, 4, ':object constructor';
is-deeply $ind-obj2.gen-num, 2, ':object constructor';

my $enc-ast = :ind-obj[5, 2, :dict{ :Type( :name<Encoding> ), :BaseEncoding( :name<MacRomanEncoding> ) } ];
my $enc-ind-obj = PDF::Storage::IndObj.new( |%($enc-ast) );
my $enc-obj = $enc-ind-obj.object;
isa-ok $enc-obj, ::('PDF::Object::Type::Encoding');
is $enc-obj.Type, 'Encoding', '$enc.Type';
is $enc-obj.BaseEncoding, 'MacRomanEncoding', '$enc.BaseEncoding';

my $objr-ast = :ind-obj[6, 0, :dict{ :Type( :name<OBJR> ), :Pg( :ind-ref[6, 1] ), :Obj( :ind-ref[6, 2]) } ];
my $objr-ind-obj = PDF::Storage::IndObj.new( |%($objr-ast) );
my $objr-obj = $objr-ind-obj.object;
isa-ok $objr-obj, ::('PDF::Object::Type::OBJR');
is $objr-obj.Type, 'OBJR', '$objr.Type';
is-deeply $objr-obj.Pg, (:ind-ref[6, 1]), '$objr.Pg';
is-deeply $objr-obj.Obj, (:ind-ref[6, 2]), '$objr.Obj';

$input = q:to"--END--";
99 0 obj
<< /Type /OutputIntent  % Output intent dictionary
/S /GTS_PDFX
/OutputCondition (CGATS TR 001 (SWOP))
/OutputConditionIdentifier (CGATS TR 001)
/RegistryName (http://www.color.org)
/DestOutputProfile 100 0 R
>>
endobj
--END--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed: $input";
$ast = $/.ast;

$ind-obj = PDF::Storage::IndObj.new( :$input, |%( $ast.kv ) );
my $oi-font-obj = $ind-obj.object;
isa-ok $oi-font-obj, ::('PDF::Object::Type::OutputIntent');
is $oi-font-obj.S, 'GTS_PDFX', 'OutputIntent S';
is $oi-font-obj.OutputCondition, 'CGATS TR 001 (SWOP)', 'OutputIntent OutputCondition';
is $oi-font-obj.RegistryName, 'http://www.color.org', 'OutputIntent RegistryName';
