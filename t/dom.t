use v6;
use Test;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Storage::IndObj;
use lib '.';
use t::Object :to-obj;

plan 27;

# crosschecks on /Type
require ::('PDF::DOM::Catalog');
my $dict = { :Outlines(:ind-ref[2, 0]), :Type<Catalog> };
my $catalog-obj = ::('PDF::DOM::Catalog').new( :$dict );
isa-ok $catalog-obj, ::('PDF::DOM::Catalog');
isa-ok $catalog-obj.Type, Str, 'catalog $.Type';
is $catalog-obj.Type, 'Catalog', 'catalog $.Type';

$dict<Type>:delete;
lives-ok {$catalog-obj = ::('PDF::DOM::Catalog').new( :$dict )}, 'catalog .new with valid /Type - lives';
isa-ok $catalog-obj.Type, Str, 'catalog $.Type';
is $catalog-obj.Type, 'Catalog', 'catalog $.Type';

$dict<Type> = :name<Wtf>;
dies-ok {::('PDF::DOM::Catalog').new( :$dict )}, 'catalog .new with invalid /Type - dies';

my $input = q:to"--END--";
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

my $actions = PDF::Grammar::PDF::Actions.new;
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed: $input";
my $ast = $/.ast;

# misc types follow

my $ind-obj = PDF::Storage::IndObj.new( :$input, |%( $ast.kv ) );
my $tt-font-obj = $ind-obj.object;
isa-ok $tt-font-obj, ::('PDF::DOM::Font::TrueType');
is $tt-font-obj.Type, 'Font', 'tt font $.Type';
is $tt-font-obj.Subtype, 'TrueType', 'tt font $.Subype';
is $tt-font-obj.Encoding, 'WinAnsiEncoding', 'tt font $.Encoding';

require ::('PDF::DOM::Font::Type0');
$dict = to-obj :dict{ :BasedFont(:name<Wingdings-Regular>), :Encoding(:name<Identity-H>) };
my $t0-font-obj = ::('PDF::DOM::Font::Type0').new( :$dict );
is $t0-font-obj.Type, 'Font', 't0 font $.Type';
is $t0-font-obj.Subtype, 'Type0', 't0 font $.Subype';
is $t0-font-obj.Encoding, 'Identity-H', 't0 font $.Encoding';

use PDF::DOM::Font::Type1;
class SubclassedType1Font is PDF::DOM::Font::Type1 {};
my $sc-font-obj = SubclassedType1Font.new;
is $sc-font-obj.Type, 'Font', 'sc font $.Type';
is $sc-font-obj.Subtype, 'Type1', 'sc font $.Subype';

my $enc-ast = :ind-obj[5, 2, :dict{ :Type( :name<Encoding> ), :BaseEncoding( :name<MacRomanEncoding> ) } ];
my $enc-ind-obj = PDF::Storage::IndObj.new( |%($enc-ast) );
my $enc-obj = $enc-ind-obj.object;
isa-ok $enc-obj, ::('PDF::DOM::Encoding');
is $enc-obj.Type, 'Encoding', '$enc.Type';
is $enc-obj.BaseEncoding, 'MacRomanEncoding', '$enc.BaseEncoding';

my $objr-ast = :ind-obj[6, 0, :dict{ :Type( :name<OBJR> ), :Pg( :ind-ref[6, 1] ), :Obj( :ind-ref[6, 2]) } ];
my $objr-ind-obj = PDF::Storage::IndObj.new( |%($objr-ast) );
my $objr-obj = $objr-ind-obj.object;
isa-ok $objr-obj, ::('PDF::DOM::OBJR');
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
isa-ok $oi-font-obj, ::('PDF::DOM::OutputIntent');
is $oi-font-obj.S, 'GTS_PDFX', 'OutputIntent S';
is $oi-font-obj.OutputCondition, 'CGATS TR 001 (SWOP)', 'OutputIntent OutputCondition';
is $oi-font-obj.RegistryName, 'http://www.color.org', 'OutputIntent RegistryName';
