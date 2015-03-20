use v6;
use Test;

plan 30;

use PDF::Storage::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use lib '.';
use t::Object :to-obj;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-ObjStm-Flate.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;

my $ind-obj = PDF::Storage::IndObj.new( :$input, |%( $ast.kv ) );
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $object = $ind-obj.object;
isa_ok $object, ::('PDF::Object::Stream');
isa_ok $object, Hash;
isa_ok $object.Length, Int, '$.Length';
is $object.Length, 167, '$.Length';
is $object.Type, 'ObjStm', '$.Type';

# crosschecks on /Type
require ::('PDF::Object::Type::Catalog');
my $dict = { :Outlines(:ind-ref[2, 0]), :Type<Catalog> };
my $catalog-obj = ::('PDF::Object::Type::Catalog').new( :$dict );
isa_ok $catalog-obj, ::('PDF::Object::Type::Catalog');
isa_ok $catalog-obj.Type, Str, 'catalog $.Type';
is $catalog-obj.Type, 'Catalog', 'catalog $.Type';

$dict<Type>:delete;
lives_ok {$catalog-obj = ::('PDF::Object::Type::Catalog').new( :$dict )}, 'catalog .new with valid /Type - lives';
isa_ok $catalog-obj.Type, Str, 'catalog $.Type (tied)';
is $catalog-obj.Type, 'Catalog', 'catalog $.Type (tied)';

$dict<Type> = :name<Wtf>;
dies_ok {::('PDF::Object::Type::Catalog').new( :$dict )}, 'catalog .new with invalid /Type - dies';

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
    // die "parse failed";
$ast = $/.ast;

$ind-obj = PDF::Storage::IndObj.new( :$input, |%( $ast.kv ) );
my $tt-font-obj = $ind-obj.object;
isa_ok $tt-font-obj, ::('PDF::Object::Type::Font::TrueType');
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
is_deeply $num-obj.content, (:real(4.2)), 'composed object $.content';
is +$num-obj, 4.2, 'composed object Num coercement';
is_deeply ~$num-obj, '4.2', 'composed object Str coercement';
is_deeply ?$num-obj, True, 'composed object Bool coercement';

my $ind-obj2 = PDF::Storage::IndObj.new( :object($num-obj), :obj-num(4), :gen-num(2) );
is_deeply $ind-obj2.object, $num-obj, ':object constructor';
is_deeply $ind-obj2.obj-num, 4, ':object constructor';
is_deeply $ind-obj2.gen-num, 2, ':object constructor';
