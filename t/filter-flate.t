use Test;

plan 11;

use PDF::Basic::Filter;
use PDF::Basic::Filter::Flate;

my $prediction-in = buf8.new: [
    0x2, 0x1, 0x0, 0x10, 0x0,
    0x2, 0x0, 0x2, 0xcd, 0x0,
    0x2, 0x0, 0x1, 0x51, 0x0,
    0x1, 0x0, 0x1, 0x70, 0x0,
    0x3, 0x0, 0x5, 0x7a, 0x0,
    0,   1,   2,   3,    4,
    ];

my $tiff-post-prediction = buf8.new: [
    0x02, 0x01, 0x00, 0x12, 0x01, 0x02, 0x12, 0x03, 0xCF, 0x12, 0x05,
    0xCF, 0x01, 0x51, 0x00, 0x02, 0x51, 0x01, 0x72, 0x51, 0x04, 0x72,
    0x56, 0x7E, 0x00, 0x00, 0x01, 0x02, 0x03, 0x05, 0x02, 0x03, 0x05,
    0x02, 0x03, 0x05
    ];

my $png-post-prediction = buf8.new: [
    0x1, 0x0, 0x10, 0x0,
    0x1, 0x2, 0xdd, 0x0,
    0x1, 0x3, 0x2e, 0x0,
    0x0, 0x1, 0x71, 0x71,
    0x0, 0x5, 0xb5, 0x93,
    1,   2,   3,    4,
    ];

is_deeply PDF::Basic::Filter::Flate.post-prediction( $prediction-in,
                                                     :Columns(4),
                                                     :Colors(3),
                                                     :Predictor(1), ),
    $prediction-in,
    "NOOP predictive filter sanity";

is_deeply PDF::Basic::Filter::Flate.post-prediction( $prediction-in,
                                                     :Columns(4),
                                                     :Colors(3),
                                                     :Predictor(2), ),
    $tiff-post-prediction,
    "TIFF predictive filter sanity";

is_deeply PDF::Basic::Filter::Flate.post-prediction( $prediction-in,
                                                     :Columns(4),
                                                     :Predictor(12), ),
    $png-post-prediction,
    "PNG predictive filter sanity";

my $rand-data = buf8.new: [
    0x12, 0x0D, 0x12, 0x0A, 0x02, 0x47, 0x8E, 0x7A, 0x1B, 0x08, 0x28, 0x21,
    0x65, 0x5B, 0x11, 0xA0, 0x02, 0x02, 0x2F, 0x3C, 0x01, 0x4B, 0x0D, 0xC9,
    0xA0, 0x37, 0x48, 0x71, 0x0E, 0x15, 0x0B, 0x1E, 0xAE, 0x02, 0xA3, 0x31,
    0x7F, 0x01, 0x05, 0x02, 0x04, 0x08, 0x06, 0x05, 0x0F, 0xFE, 0x01, 0x1A,
    ];

for None => 1, TIFF => 2, PNG => 10 {
    my ($desc, $Predictor) = .kv;

    my $prediction = PDF::Basic::Filter::Flate.prediction( $rand-data,
                                                           :Columns(4),
                                                           :$Predictor, );

    my $post-prediction = PDF::Basic::Filter::Flate.post-prediction( $prediction,
                                                                     :Columns(4),
                                                                     :$Predictor, );

    is_deeply $post-prediction, $rand-data, "$desc predictor ($Predictor) - appears lossless";
}

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Basic;
use PDF::Basic::Util :unbox;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-ObjStm-Flate.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;

my $pdf = PDF::Basic.new( :$input );

my $dict = unbox( |%$ast )<dict>;
my $raw-content = $pdf.stream-data( |%$ast )[0];
my $content;

lives_ok { $content = PDF::Basic::Filter.decode( $raw-content, :$dict ) }, 'basic content decode - lives';

my $content-expected = "16 0 17 141 <</BaseFont/CourierNewPSMT/Encoding/WinAnsiEncoding/FirstChar 111/FontDescriptor 15 0 R/LastChar 111/Subtype/TrueType/Type/Font/Widths[600]>><</BaseFont/TimesNewRomanPSMT/Encoding/WinAnsiEncoding/FirstChar 32/FontDescriptor 14 0 R/LastChar 32/Subtype/TrueType/Type/Font/Widths[250]>>";

is_deeply $content, $content-expected,
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

is_deeply my $result=PDF::Basic::Filter.decode($flate-enc, :%dict),
    $flate-dec, "Flate with PNG predictors - decode";

my $re-encoded = PDF::Basic::Filter.encode($result, :%dict);

is_deeply PDF::Basic::Filter.decode($re-encoded, :%dict),
    $flate-dec, "Flate with PNG predictors - encode/decode round-trip";

dies_ok { PDF::Basic::Filter.decode('This is not valid input', :%dict) },
    q{Flate dies if invalid characters are passed to decode};
