use Test;
# this test based on PDF-API2/t/filter-runlengthdecode.t
plan 7;

use PDF::Storage::Filter::RunLength;
use PDF::Storage::Filter;

my $in = '--- Look at this test string. ---';
my $out = "\x[fe]-\x01 L\xffo\x16k at this test string. \xfe-";
my $filter = PDF::Storage::Filter::RunLength.new;

is $filter.encode($in),
   $out,
   q{RunLength test string is encoded correctly};

is $filter.decode($out),
   $in,
   q{RunLength test string is decoded correctly};

dies-ok { $filter.decode($out, :eod) },
    q{RunLength missing EOD marker is handled correctly};

my %dict = :Filter<RunLengthDecode>;

is(PDF::Storage::Filter.decode($out, :%dict),
   $in,
   q{ASCIIHex test string is decoded correctly});

is(PDF::Storage::Filter.encode($in, :%dict),
   $out,
   q{ASCIIHex test string is encoded correctly});

# Add the end-of-document marker
$out ~= "\x80";

is $filter.encode($in, :eod),
   $out,
   q{RunLength test string with EOD marker is encoded correctly};

is $filter.decode($out, :eod),
   $in,
   q{RunLength test string with EOD marker is decoded correctly};

