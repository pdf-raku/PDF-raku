use Test;
# this test based on PDF-API2/t/filter-runlengthdecode.t
plan 5;

use PDF::Storage::Filter::RunLength;
use PDF::Storage::Filter;

my $in = '--- Look at this test string. ---';
my $out = "\x[fe]-\x01 L\xffo\x16k at this test string. \x[fe]-";

my %dict = :Filter<RunLengthDecode>;

dies-ok { PDF::Storage::Filter.decode($out, :%dict) },
    q{RunLength missing EOD marker is handled correctly};

$out ~= "\x[80]";

is-deeply ~PDF::Storage::Filter.encode($in, :%dict),
   $out,
   q{RunLength test string is encoded correctly};

is PDF::Storage::Filter.decode($out, :%dict),
   $in,
   q{RunLength test string is decoded correctly};

is(PDF::Storage::Filter.decode($out, :%dict),
   $in,
   q{ASCIIHex test string is decoded correctly});

is-deeply(~PDF::Storage::Filter.encode($in, :%dict),
   $out,
   q{ASCIIHex test string is encoded correctly});


