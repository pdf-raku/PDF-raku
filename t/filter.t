use Test;

plan 33;

use PDF::Basic::Filter;

my $empty = '';
my $latin-chars = [~] chr(0)..chr(0xFF);
my $low-repeat = 'A' x 200;
my $high-repeat = chr(180) x 200;
my $longish = [~] (map { $_ x 3 }, $latin-chars.comb ) x 2;
my $wide-chars = "Τη γλώσσα μου έδωσαν ελληνική";

for qw<ASCIIHexDecode FlateDecode RunLengthDecode> -> $filter-name {

    my %dict = Filter => $filter-name;

    dies_ok { PDF::Basic::Filter.encode($wide-chars, :%dict) }, $filter-name ~' input chars > \xFF - dies';

    for :$empty, :$latin-chars, :$low-repeat, :$high-repeat, :$longish {
        my ($name, $input) = .kv;

        my $output;
        lives_ok { $output = PDF::Basic::Filter.encode($input, :%dict) }, "$filter-name encoding - lives";

        is_deeply PDF::Basic::Filter.decode($output, :%dict), $input, "$filter-name roundtrip: $name"
            or diag :$input.perl;

    }
}
