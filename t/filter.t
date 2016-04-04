use Test;

plan 80;

use PDF::Storage::Filter;

my $empty = '';
my $latin-chars = [~] chr(0)..chr(0xFF);
my $low-repeat = 'A' x 200;
my $high-repeat = chr(180) x 200;
my $longish = [~] (map { $_ x 3 }, $latin-chars.comb ) x 2;
my $wide-chars = "Τη γλώσσα μου έδωσαν ελληνική";

for 'ASCIIHexDecode', 'FlateDecode', 'RunLengthDecode', ['FlateDecode', 'RunLengthDecode'] -> $filter {

    my $filter-name = $filter.join: ', ';
    my %dict = Filter => $filter;

    dies-ok { PDF::Storage::Filter.encode($wide-chars, :%dict) }, $filter-name ~' decode chars > \xFF - dies';

    for :$empty, :$latin-chars, :$low-repeat, :$high-repeat, :$longish {
        my ($name, $input) = .kv;

        my $encoded;
        lives-ok { $encoded = PDF::Storage::Filter.encode($input, :%dict) }, $filter-name ~' encoding - lives';
	isnt $input, $encoded, $filter-name ~' is encoded'
	     unless $input eq '';
	     
        my $decoded;
        lives-ok { $decoded = PDF::Storage::Filter.decode($encoded, :%dict); }, $filter-name ~' decoding - lives';
	is $decoded, $input, "$filter-name roundtrip: $name"
            or diag :$input.perl;

    }
}
