use Test;

plan 18;

use PDF::Basic::Filter::ASCIIHex;
use PDF::Basic::Filter::Flate;
use PDF::Basic::Filter::RunLength;

my $empty = '';
my $latin-chars = [~] chr(0)..chr(0xFF);
my $low-repeat = 'A' x 200;
my $high-repeat = chr(180) x 200;
my $longish = [~] (map { $_ x 3 }, $latin-chars.comb ) x 2;
my $wide-chars = "Τη γλώσσα μου έδωσαν ελληνική";

for ( :run-length(PDF::Basic::Filter::RunLength),
      :flate(PDF::Basic::Filter::Flate),
      :ascii-hex(PDF::Basic::Filter::ASCIIHex),
    ) {
    my ($filter-type, $class) = .kv;

    my $filter = $class.new;

    dies_ok { $filter.encode($wide-chars) }, $filter-type ~' input chars > \xFF - dies';

    for :$empty, :$latin-chars, :$low-repeat, :$high-repeat, :$longish {
        my ($name, $input) = .kv;

        my $output = $filter.encode($input);

        is_deeply $filter.decode($output), $input, "$filter-type roundtrip: $name"
            or diag :$input.perl;

    }
}
