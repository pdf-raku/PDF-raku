use v6;
use Test;

plan 20;

use PDF::Tools::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-ObjStm-Flate.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;

my $ind-obj = PDF::Tools::IndObj.new-delegate( :$input, |%( $ast.kv ) );
isa_ok $ind-obj, ::('PDF::Tools::IndObj')::('Stream');
isa_ok $ind-obj.dict, Hash, '$.dict';
is_deeply $ind-obj.Length, (:int(167)), '$.Length';
is_deeply $ind-obj.Type, (:name<ObjStm>), '$.Type';
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';

# crosschecks on /Type
require ::('PDF::Tools::IndObj::Type::Catalog');
my $dict = { :Pages(:ind-ref[3, 0]), :Outlines(:ind-ref[2, 0]), :Type(:name<Catalog>) };
my $catalog-obj = ::('PDF::Tools::IndObj::Type::Catalog').new( :$dict );
isa_ok $catalog-obj, ::('PDF::Tools::IndObj::Type::Catalog');
is_deeply $catalog-obj.Type, (:name<Catalog>), 'catalog $.Type';

$dict<Type>:delete;
lives_ok {$catalog-obj = ::('PDF::Tools::IndObj::Type::Catalog').new( :$dict )}, 'catalog .new with valid /Type - lives';
is_deeply $catalog-obj.Type, (:name<Catalog>), 'catalog $.Type (tied)';

$dict<Type> = :name<Wtf>;
dies_ok {::('PDF::Tools::IndObj::Type::Catalog').new( :$dict )}, 'catalog .new with invalid /Type - dies';

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

my $tt-font-obj = PDF::Tools::IndObj.new-delegate( :$input, |%( $ast.kv ) );
isa_ok $tt-font-obj, ::('PDF::Tools::IndObj::Type::Font::TrueType');
is_deeply $tt-font-obj.Type, (:name<Font>), 'tt font $.Type';
is_deeply $tt-font-obj.Subtype, (:name<TrueType>), 'tt font $.Subype';
is_deeply $tt-font-obj.Encoding, (:name<WinAnsiEncoding>), 'tt font $.Encoding';

require ::('PDF::Tools::IndObj::Type::Font::Type0');
$dict = { :BasedFont(:name<Wingdings-Regular>), :Encoding(:name<Identity-H>) };
my $t0-font-obj = ::('PDF::Tools::IndObj::Type::Font::Type0').new( :$dict );
is_deeply $t0-font-obj.Type, (:name<Font>), 't0 font $.Type';
is_deeply $t0-font-obj.Subtype, (:name<Type0>), 't0 font $.Subype';
is_deeply $t0-font-obj.Encoding, (:name<Identity-H>), 't0 font $.Encoding';

use PDF::Tools::IndObj::Type::Font::Type1;
class SubclassedType1Font is PDF::Tools::IndObj::Type::Font::Type1 {};
my $sc-font-obj = SubclassedType1Font.new;
is_deeply $sc-font-obj.Type, (:name<Font>), 'sc font $.Type';
is_deeply $sc-font-obj.Subtype, (:name<Type1>), 'sc font $.Subype';

