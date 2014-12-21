use Test;

plan 10;

use PDF::Basic::Filter::ASCIIHex;
use PDF::Basic::Filter::RunLength;

my $empty = '';
my $latin-chars = [~] chr(0)..chr(0xFF);
my $longish = 'abc' x 200;
my $low-repeat = 'A' x 200;
my $high-repeat = chr(180) x 200;

for ( :run-length(PDF::Basic::Filter::RunLength),
      :ascii-hex(PDF::Basic::Filter::ASCIIHex),
    ) {
    my ($filter-type, $class) = .kv;

    my $filter = $class.new;

    for :$empty, :$latin-chars, :$longish, :$low-repeat, :$high-repeat {
        my ($name, $input) = .kv;

        my $output = $filter.encode($input);

        is_deeply $filter.decode($output), $input, "$filter-type roundtrip: $name"
            or diag :$input.perl;

    }
}
