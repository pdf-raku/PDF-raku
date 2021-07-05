use v6;
use Test;
plan 49;

use PDF::IO::Filter::Predictors;
use PDF::IO::Filter;

my $encode-in = blob8.new: [
    0x2, 0x1, 0x0, 0x10, 0x0,
    0x2, 0x0, 0x2, 0xcd, 0x0,
    0x2, 0x0, 0x1, 0x51, 0x0,
    0x1, 0x0, 0x1, 0x70, 0x0,
    0x3, 0x0, 0x5, 0x7a, 0x0,
    0,   1,   2,   3,    4,
    ];

my $tiff-decode = blob8.new: [
    0x02, 0x01, 0x00, 0x12, 0x01, 0x02, 0x12, 0x03, 0xCF, 0x12, 0x05,
    0xCF, 0x01, 0x51, 0x00, 0x02, 0x51, 0x01, 0x72, 0x51, 0x04, 0x72,
    0x56, 0x7E,
    ];

my $png-decode = blob8.new: [
    0x1, 0x0, 0x10, 0x0,
    0x1, 0x2, 0xdd, 0x0,
    0x1, 0x3, 0x2e, 0x0,
    0x0, 0x1, 0x71, 0x71,
    0x0, 0x5, 0xb5, 0x93,
    1,   2,   3,    4,
    ];

is-deeply PDF::IO::Filter::Predictors.decode( $encode-in,
                                              :Columns(4),
                                              :Colors(3),
                                              :Predictor(1), ),
    $encode-in,
    "NOOP predictive filter sanity";

my $tiff-in = blob8.new: $encode-in.head(24);
is-deeply PDF::IO::Filter::Predictors.decode( $tiff-in,
                                              :Columns(4),
                                              :Colors(3),
                                              :Predictor(2), ),
    $tiff-decode,
    "TIFF predictive filter sanity";

is-deeply PDF::IO::Filter::Predictors.decode( $encode-in,
                                              :Columns(4),
                                              :Predictor(12), ),
    $png-decode,
    "PNG predictive filter sanity";

my $rand-data = blob8.new: [
    0x12, 0x0D, 0x12, 0x0A, 0x02, 0x47, 0x8E, 0x7A,
    0x1B, 0x08, 0x28, 0x21, 0x65, 0x5B, 0x11, 0xA0,
    0x02, 0x02, 0x2F, 0x3C, 0x01, 0x4B, 0x0D, 0xC9,
    0xA0, 0x37, 0x48, 0x71, 0x0E, 0x15, 0x0B, 0x1E,
    0xAE, 0x02, 0xA3, 0x31, 0x7F, 0x01, 0x05, 0x02,
    0x04, 0x08, 0x06, 0x05, 0x0F, 0xFE, 0x01, 0x1A,
    0x76, 0x18, 0xED, 0x58, 0xB8, 0x83, 0x87, 0x7C,
    0x7F, 0x80, 0x3C, 0x20, 0xE9, 0x9B, 0x04, 0xE2 ,
    ];

my %expected-bpc-pref := {
    4 => {
        2 => blob8.new(18,251,21,248,2,69,71,252,27,253,32,9,101,246,198,159,2,0,45,29,1,74,194,204,160,151,17,57,14,23,246,19,174,100,161,158,127,146,4,13,4,4,14,15,15,255,19,25,118,162,213,123,184,219,4,245,127,17,188,244,233,178,121,238),
    },
    8 => {
        2 => blob8.new(18,13,0,253,240,61,140,51,27,8,13,25,61,58,172,69,2,2,45,58,210,15,12,126,160,55,168,58,198,164,253,9,174,2,245,47,220,208,134,1,4,8,2,253,9,249,242,28,118,24,119,64,203,43,207,249,127,128,189,160,173,123,27,71),
    },
    16 => {
        2 => blob8.new(18,13,18,10,240,58,124,112,24,193,153,167,74,83,233,127,2,2,47,60,255,73,222,141,158,236,58,168,109,222,194,173,174,2,163,49,208,255,97,209,133,7,1,3,11,246,251,21,118,24,237,88,66,107,154,36,198,253,180,164,106,27,200,194),
    },
};

for flat 1, 2, 10 .. 15 -> $Predictor {
    my $desc = do given $Predictor { when 2 { 'TIFF' }; when 1 { 'no-op'}; default {'PNG'} };

    my $encode = PDF::IO::Filter::Predictors.encode( $rand-data,
                                                     :Columns(4),
                                                     :$Predictor, );

    my $decode = PDF::IO::Filter::Predictors.decode( $encode,
                                                     :Columns(4),
                                                     :$Predictor, );

    is-deeply $decode, $rand-data, "$desc predictor ($Predictor) - appears lossless";

    for 4, 8, 16, 32 -> $BitsPerComponent {
        my $encode2c = PDF::IO::Filter::Predictors.encode( $rand-data,
						       :Columns(4),
						       :Colors(2),
                                                       :$BitsPerComponent,
						       :$Predictor, );
        is-deeply($encode2c, $_, "$desc predictor ($Predictor) multi-channel $BitsPerComponent bpc - encoding")
            with  %expected-bpc-pref{$BitsPerComponent}{$Predictor};
    
        my $decode2c = PDF::IO::Filter::Predictors.decode( $encode2c,
						           :Columns(4),
						           :Colors(2),
                                                           :$BitsPerComponent,
						           :$Predictor, );

        is-deeply $decode2c, $rand-data, "$desc predictor ($Predictor) multi-channel $BitsPerComponent bpc - appears lossless";
    }
}

my $dict = { :Filter<FlateDecode>, :DecodeParms{ :Predictor(12), :Columns(4) } };

my $rand-chrs = [~] $rand-data.list.grep({ $_ <= 0xFF }).map: { .chr };

my $encoded;
lives-ok {$encoded = PDF::IO::Filter.encode($rand-chrs, :$dict)}, "$dict<Filter> encode with encode";

my $decoded;
lives-ok {$decoded = PDF::IO::Filter.decode($encoded, :$dict)}, "$dict<Filter> encode with encode";

is-deeply $decoded.Str, $rand-chrs, "$dict<Filter> round-trip with encode";

