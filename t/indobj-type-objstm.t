use v6;
use Test;

plan 5;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-ObjStm-Flate.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Tools::IndObj.new-delegate( |%$ast, :$input );
isa_ok $ind-obj, ::('PDF::Tools::IndObj')::('Type::ObjStm');

my $objstm;
lives_ok { $objstm = $ind-obj.decode }, 'basic content decode - lives';

my $expected-objstm = [
    [16, 0,
     "<</BaseFont/CourierNewPSMT/Encoding/WinAnsiEncoding/FirstChar 111/FontDescriptor 15 0 R/LastChar 111/Subtype/TrueType/Type/Font/Widths[600]>>",
    ],
    [17, 0,
     "<</BaseFont/TimesNewRomanPSMT/Encoding/WinAnsiEncoding/FirstChar 32/FontDescriptor 14 0 R/LastChar 32/Subtype/TrueType/Type/Font/Widths[250]>>",
    ],
    ];

is_deeply $objstm, $expected-objstm, 'decoded index as expected';
my $objstm-recompressed = $ind-obj.encode;

my $ast2;
lives_ok { $ast2 = $ind-obj.ast }, '$.ast - lives';

my $ind-obj2 = PDF::Tools::IndObj.new-delegate( |%$ast2 );
my $objstm-roundtrip = $ind-obj2.decode( $objstm-recompressed );

is_deeply $objstm, $objstm-roundtrip, 'encode/decode round-trip';

