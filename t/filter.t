use v6;
use Test;
plan 92;

use PDF::IO::Filter;

my $empty = '';
my $latin-chars = [~] chr(0)..chr(0xFF);
my $low-repeat = 'A' x 200;
my $high-repeat = chr(180) x 200;
my $longish = [~] (map { $_ x 3 }, $latin-chars.comb ) x 2;
my $wide-chars = "Τη γλώσσα μου έδωσαν ελληνική";

for 'ASCIIHexDecode', 'FlateDecode', 'RunLengthDecode', ['FlateDecode', 'RunLengthDecode'] -> $Filter {

    my $filter-name = $Filter.join: ', ';
    my %dict = :$Filter;

    dies-ok { PDF::IO::Filter.encode($wide-chars, :%dict) }, $filter-name ~' decode chars > \xFF - dies';

    for :$empty, :$latin-chars, :$low-repeat, :$high-repeat, :$longish {
        my ($name, $input) = .kv;

        my $encoded;
        lives-ok { $encoded = PDF::IO::Filter.encode($input, :%dict) }, $filter-name ~' encoding - lives';
	isnt $input, $encoded, $filter-name ~' is encoded'
	     unless $input eq '';
	     
        my $decoded;
        lives-ok { $decoded = PDF::IO::Filter.decode($encoded, :%dict); }, $filter-name ~' decoding - lives';
	is $decoded, $input, "$filter-name roundtrip: $name"
            or diag :$input.raku;

    }

    my Blob $encoded-buf;
    my Blob $decoded-buf = $latin-chars.encode("latin-1");
    lives-ok { $encoded-buf = PDF::IO::Filter.encode($decoded-buf, :%dict); }, $filter-name ~' Blob encoding - lives';
    lives-ok { $decoded-buf = PDF::IO::Filter.decode($encoded-buf, :%dict); }, $filter-name ~' Blob decoding - lives';
    is $decoded-buf.decode("latin-1"), $latin-chars, 'Blob round-trip';
}
