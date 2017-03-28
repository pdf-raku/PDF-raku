use v6;
use Test;
plan 14;

use PDF::IO::Util :resample;

my $buf;
my uint8 @bytes = (10, 20, 30, 40, 50, 60);
my buf8 $bytes .= new: @bytes;

is-deeply ($buf=resample(@bytes, 8, 4)), buf8.new(0, 10, 1, 4, 1, 14, 2, 8, 3, 2, 3, 12), '4 bit resample';
is-deeply resample($buf, 4, 8), $bytes, 'resample round-trip: 8 => 4 => 8';

is-deeply resample($bytes, 8, 8), $bytes, '8 bit resample';

is-deeply ($buf=resample(@bytes, 8, 16)), buf16.new(2580, 7720, 12860), '16 bit resample';
is-deeply resample($buf, 16, 8), $bytes, 'resample round-trip: 16 => 8 => 16';

is-deeply ($buf=resample([1415192289,], 32, 8)), buf8.new(84, 90, 30, 225), '32 => 8 resample';
is-deeply ($buf= resample([2 ** 32 - 1415192289 - 1,], 32, 8)), buf8.new(255-84, 255-90, 255-30, 255-225), '32 => 8 resample (twos comp)';

quietly {
    is-deeply ($buf=resample(@bytes, 8, 6)), buf8.new(2, 33, 16, 30, 10, 3, 8, 60), '6 bit resample';
    is-deeply resample($buf, 6, 8), $bytes, 'resample round-trip: 8 => 6 => 8';

    is-deeply ($buf=resample([109], 8, 1)), buf8.new(0, 1, 1, 0, 1, 1, 0, 1), '8 => 1 (bit) resample';
    is-deeply ($buf=resample($buf, 1, 8)), buf8.new(109), '8 => 1 => 8 round trip';
}

my $shaped;
is-deeply ($shaped=resample(@bytes, 8, [1, 3, 2])).values, (10, 1318440, 12860), '8 => [1, 3, 2] resample';
is-deeply array[uint8].new(resample($shaped, [1, 3, 2], 8)), @bytes, '[1, 3, 2] => 8 resample';

my uint32 @in[4;3] = ([1, 16, 0], [1, 741, 0], [1, 1030, 0], [1, 1446, 0]);
my $W = [1, 2, 1];
my $out = buf8.new(1, 0, 16, 0,  1, 2, 229, 0,  1, 4, 6, 0,  1, 5, 166, 0);

is-deeply resample(@in, $W, 8), $out, '$W[1, 2, 1] 8 bit sample';
