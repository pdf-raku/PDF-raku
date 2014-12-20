use Test;
# this test based on PDF-API2/t/filter-runlengthdecode.t
plan 10;

use PDF::Basic::Filter::RunLength;

my $in = '--- Look at this test string. ---';
my $out = "\x[fe]-\x01 L\xffo\x16k at this test string. \xfe-";
my $filter = PDF::Basic::Filter::RunLength.new;

is_deeply $filter.encode($in),
   $out,
   q{RunLength test string is encoded correctly};

is_deeply $filter.decode($out),
   $in,
   q{RunLength test string is decoded correctly};

dies_ok { $filter.decode($out, :eod) },
    q{RunLength missing EOD marker is handled correctly};

# Add the end-of-document marker
$out ~= "\x80";

is $filter.encode($in, :eod),
   $out,
   q{RunLength test string with EOD marker is encoded correctly};

is $filter.decode($out, :eod),
   $in,
   q{RunLength test string with EOD marker is decoded correctly};

my $empty = '';
my $latin-chars = [~] chr(0)..chr(0xFF);
my $longish = 'abc' x 200;
my $low-repeat = 'A' x 200;
my $high-repeat = chr(180) x 200;

for :$empty, :$latin-chars, :$longish, :$low-repeat, :$high-repeat {
    my ($name, $input) = .kv;

    my $output = $filter.encode($input);

    is_deeply $filter.decode($output), $input, "roundtrip: $name"
        or diag :$input.perl;
}
