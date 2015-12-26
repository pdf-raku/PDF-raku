use Test;

plan 5;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Storage::Input;
use PDF::Storage::Filter;
use PDF::Storage::IndObj;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-ObjStm-Flate.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;
my $pdf-input = PDF::Storage::Input.coerce( $input );
my $ind-obj = PDF::Storage::IndObj.new( :$input, |%ast );
my $dict = $ind-obj.object;
my $raw-content = $pdf-input.stream-data( |%ast )[0];
my $content;

lives-ok { $content = PDF::Storage::Filter.decode( $raw-content, :$dict ) }, 'basic content decode - lives';

my $content-expected = "16 0 17 141 <</BaseFont/CourierNewPSMT/Encoding/WinAnsiEncoding/FirstChar 111/FontDescriptor 15 0 R/LastChar 111/Subtype/TrueType/Type/Font/Widths[600]>><</BaseFont/TimesNewRomanPSMT/Encoding/WinAnsiEncoding/FirstChar 32/FontDescriptor 14 0 R/LastChar 32/Subtype/TrueType/Type/Font/Widths[250]>>";

is $content, $content-expected,
    q{basic Flate decompression};

my $flate-enc = [104, 222, 98, 98, 100, 16, 96, 96, 98, 96,
186, 10, 34, 20, 129, 4, 227, 2, 32, 193, 186, 22, 72, 48, 203, 131,
8, 37, 16, 33, 13, 34, 50, 65, 74, 30, 128, 88, 203, 64, 196, 82, 16,
119, 23, 144, 224, 206, 7, 18, 82, 7, 128, 4, 251, 121, 32, 97, 117,
6, 72, 84, 1, 13, 96, 100, 72, 5, 178, 24, 24, 24, 169, 78, 252, 103,
20, 123, 15, 16, 96, 0, 153, 243, 13, 60].chrs;

my $flate-dec = [1, 0, 16, 0, 1, 2, 229, 0, 1, 4, 6, 0, 1, 5, 166, 0,
1, 10, 83, 0, 1, 13, 114, 0, 1, 16, 148, 0, 1, 19, 175, 0, 1, 22, 24,
0, 1, 24, 248, 0, 1, 27, 158, 0, 1, 30, 67, 0, 1, 32, 253, 0, 1, 43,
108, 0, 1, 69, 44, 0, 1, 76, 251, 0, 1, 134, 199, 0, 1, 0, 116, 0, 2,
0, 217, 0, 2, 0, 217, 1, 2, 0, 217, 2, 2, 0, 217, 3, 2, 0, 217, 4, 2,
0, 217, 5, 2, 0, 217, 6, 2, 0, 217, 7, 2, 0, 217, 8, 2, 0, 217, 9, 2,
0, 217, 10, 2, 0, 217, 11, 2, 0, 217, 12, 2, 0, 217, 13, 2, 0, 217,
14, 2, 0, 217, 15, 2, 0, 217, 16, 2, 0, 217, 17, 1, 1, 239, 0].chrs;

my %dict = :Filter<FlateDecode>, :DecodeParms{ :Predictor(12), :Columns(4) };

is my $result=PDF::Storage::Filter.decode($flate-enc, :%dict),
    $flate-dec, "Flate with PNG predictors - decode";

my $re-encoded = PDF::Storage::Filter.encode($result, :%dict);

is PDF::Storage::Filter.decode($re-encoded, :%dict),
    $flate-dec, "Flate with PNG predictors - encode/decode round-trip";

dies-ok { PDF::Storage::Filter.decode('This is not valid input', :%dict) },
    q{Flate dies if invalid characters are passed to decode};
