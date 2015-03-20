use v6;
use Test;
plan 11;

use PDF::Storage::Util :resample;

my $result;

my $bytes = (10, 20, 30, 40, 50, 60).list.item;

is_deeply $result=resample($bytes,  8, 4), (0, 10, 1, 4, 1, 14, 2, 8, 3, 2, 3, 12).list.item, '4 bit resample';
is_deeply resample($result, 4, 8), $bytes, 'resample round-trip: 8 => 4 => 8';

is_deeply resample($bytes,  8, 8), $bytes, '8 bit resample';

is_deeply $result=resample($bytes,  8, 16), (2580, 7720, 12860).list.item, '16 bit resample';
is_deeply resample($result, 16, 8), $bytes, 'resample round-trip: 16 => 8 => 16';

is_deeply $result=resample($bytes,  8, 6), (2, 33, 16, 30, 10, 3, 8, 60).list.item, '6 bit resample';
is_deeply resample($result, 6, 8), $bytes, 'resample round-trip: 8 => 6 => 8';

is_deeply $result=resample([109], 8, 1), (0,1,1,0,1,1,0,1).list.item, ' 8 => 1 (bit) resample';
is_deeply resample($result, 1, 8), (109).list.item, '8 => 1 => 8 round trip';

is_deeply $result=resample($bytes, 8, [1, 3, 2]), [[10, 1318440, 12860]].list.item, '  8 => [1, 3, 2] resample';
is_deeply $result=resample($result, [1, 3, 2], 8), $bytes, '  [1, 3, 2] => 8 resample';

