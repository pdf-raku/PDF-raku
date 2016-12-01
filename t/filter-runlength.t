use v6;
use Test;
# this test based on PDF-API2/t/filter-runlengthdecode.t
plan 15;

use PDF::IO::Filter::RunLength;
use PDF::IO::Filter;

my $in = "--- Look at this test string.\r\n ---";
my $out = "\x[fe]-\x01 L\xffo\x18k at this test string.\r\n \x[fe]-";

my %dict = :Filter<RunLengthDecode>;

dies-ok { PDF::IO::Filter.decode($out, :%dict) },
    q{RunLength missing EOD marker is handled correctly};

$out ~= "\x[80]";

is-deeply ~PDF::IO::Filter.encode($in, :%dict),
   $out,
   q{RunLength test string is encoded correctly};

is PDF::IO::Filter.decode($out, :%dict),
   $in,
   q{RunLength test string is decoded correctly};

for :empty(''), :single-byte('a'), :min-run('aa'), :min-lit('ab'), :long-run('a' x 130), :long-lit([~] ' ' .. 0xFE.chr) {
    my $test = .key;
    my $in = .value;
    my $round-trip;
    lives-ok {
        my $out = ~PDF::IO::Filter.encode($in, :%dict);
        $round-trip = ~PDF::IO::Filter.decode($out, :%dict);
    }, "$test round trip";
    is $round-trip, $in, "RunLength $test round-trip";
}
