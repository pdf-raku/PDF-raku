use v6;
use Test;
plan 14;

use PDF::Storage::Util :resample;

my @result;
my $bytes = (10, 20, 30, 40, 50, 60).list.item;

is-deeply (@result=resample($bytes,  8, 4)), [0, 10, 1, 4, 1, 14, 2, 8, 3, 2, 3, 12], '4 bit resample';
is-deeply resample(@result, 4, 8), $bytes, 'resample round-trip: 8 => 4 => 8';

is-deeply resample($bytes,  8, 8), $bytes, '8 bit resample';

is-deeply (@result=resample($bytes,  8, 16)), [2580, 7720, 12860], '16 bit resample';
is-deeply resample(@result, 16, 8), $bytes, 'resample round-trip: 16 => 8 => 16';

is-deeply (@result=resample([1415192289,], 32, 8)), [84, 90, 30, 225], '32 => 8 resample';
is-deeply (@result= resample([2 ** 32 - 1415192289 - 1,], 32, 8)), [255-84, 255-90, 255-30, 255-225], '32 => 8 resample (twos comp)';

quietly {
    is-deeply (@result=resample($bytes,  8, 6)), [2, 33, 16, 30, 10, 3, 8, 60], '6 bit resample';
    is-deeply resample(@result, 6, 8), $bytes, 'resample round-trip: 8 => 6 => 8';

    is-deeply (@result=resample([109], 8, 1)), [0, 1, 1, 0, 1, 1, 0, 1], ' 8 => 1 (bit) resample';
    is-deeply (@result=resample(@result, 1, 8)), [109], '8 => 1 => 8 round trip';
}

is-deeply (@result=resample($bytes, 8, [1, 3, 2])), [[10, 1318440, 12860],], '  8 => [1, 3, 2] resample';
is-deeply resample(@result, [1, 3, 2], 8), $bytes, '[1, 3, 2] => 8 resample';

my $in = [[1, 16, 0], [1, 741, 0], [1, 1030, 0], [1, 1446, 0]];
my $W = [1, 2, 1];
my $out = [1, 0, 16, 0,  1, 2, 229, 0,  1, 4, 6, 0,  1, 5, 166, 0];

is resample($in, $W, 8), $out, '$W[1, 2, 1] 8 bit sample';
