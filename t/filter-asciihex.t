use v6;
use Test;
plan 10;

use PDF::IO::Filter::ASCIIHex;
use PDF::IO::Filter;

my $in = 'This is a test string.';
my $out = '546869732069732061207465737420737472696E672E';

dies-ok { PDF::IO::Filter::ASCIIHex.decode($out, :eod) },
    q{ASCIIHex missing eod marker handled};

# Add the end-of-document marker
$out ~= '>';

is(PDF::IO::Filter::ASCIIHex.encode($in),
   $out,
   q{ASCIIHex test string is encoded correctly});

is(PDF::IO::Filter::ASCIIHex.decode($out),
   $in,
   q{ASCIIHex test string is decoded correctly});

my %dict = :Filter<ASCIIHexDecode>;

is(PDF::IO::Filter.decode($out, :%dict),
   $in,
   q{ASCIIHex test string is decoded correctly});

is(PDF::IO::Filter.encode($in, :%dict).Str,
   $out,
   q{ASCIIHex test string is encoded correctly});

is(PDF::IO::Filter::ASCIIHex.encode($in, :eod),
   $out,
   q{ASCIIHex test string with EOD marker is encoded correctly});

is(PDF::IO::Filter::ASCIIHex.decode($out),
   $in,
   q{ASCIIHex test string with EOD marker is decoded correctly});

# Ensure the filter is case-insensitive
$out = uc($out);
is(PDF::IO::Filter::ASCIIHex.decode($out),
   $in,
   q{ASCIIHex is case-insensitive});


# Check for death if invalid characters are included
dies-ok { PDF::IO::Filter::ASCIIHex.decode('This is not valid input') },
    q{ASCIIHex dies if invalid characters are passed to decode};

# PDF 1.7, section 7.4.2:
# "If the filter encounters the EOD marker after reading an odd number
# of hexadecimal digits, it shall behave as if a 0 (zero) followed the
# last digit"
my $odd_out = 'FF00F>';
my $expected_bytes = '255 0 240';
my $actual_bytes = PDF::IO::Filter::ASCIIHex.decode($odd_out).Str.comb>>.ord.join: ' ';
is($actual_bytes,
   $expected_bytes,
   q{ASCIIHex handles odd numbers of characters correctly});

