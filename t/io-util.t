use v6;
use Test;
plan 19;

use PDF::IO::Util :pack;

my Blob $buf;
my uint8 @bytes = (10, 20, 30, 40, 50, 60);
my blob8 $bytes .= new: @bytes;

is-deeply ($buf = unpack(@bytes, 4)), blob8.new(0,10, 1,4, 1,14, 2,8, 3,2, 3,12), '4 bit unpack';
is-deeply pack($buf, 4), $bytes, 'pack round-trip: 8 => 4 => 8';

is-deeply pack($bytes, 8), $bytes, '8 bit pack';
is-deeply unpack($bytes, 8), $bytes, '8 bit unpack';

is-deeply ($buf = unpack(@bytes, 16)), blob16.new(2580, 7720, 12860), '16 bit unpack';
is-deeply pack($buf, 16, ), $bytes, 'resample round-trip: 16 => 8 => 16';

is-deeply ($buf = pack([1415192289,], 32)), blob8.new(84, 90, 30, 225), '32 bit packing';
is-deeply ($buf = pack([2 ** 32 - 1415192289 - 1,], 32)), blob8.new(255-84, 255-90, 255-30, 255-225), '32 bit packing (twos comp)';

quietly {
    # variable bit packing is only implemented in Raku
    use PDF::IO::Util :pack-raku;
    is-deeply ($buf = unpack-raku(@bytes, 6)), blob8.new(2, 33, 16, 30, 10, 3, 8, 60), '6 bit big-endian unpack';
    is-deeply pack-raku($buf, 6), $bytes, 'resample round-trip: 8 => 6 => 8';

    is-deeply ($buf = unpack([109], 1)), blob8.new(0, 1, 1, 0, 1, 1, 0, 1), '1 bit unpack';
    is-deeply pack($buf, 1), blob8.new(109), '8 => 1 => 8 round trip';
}

my $shaped;
is-deeply ($shaped = unpack(@bytes, [1, 3, 2])).values, (10, 1318440, 12860), '[1, 3, 2] unpack';
is-deeply array[uint8].new(pack($shaped, [1, 3, 2])), @bytes, '[1, 3, 2] => 8 pack';

my uint64 @in[4;3] = [1, 16, 0], [1, 741, 0], [1, 1030, 0], [1, 1446, 0];
my @W = [1, 2, 1];
my $out = buf8.new(1, 0, 16, 0,  1, 2, 229, 0,  1, 4, 6, 0,  1, 5, 166, 0);

is-deeply pack(@in, @W), $out, '@W[1, 2, 1] packing';
is-deeply unpack($out, @W).list, @in.list;

@W = packing-widths(@in, 3);
# zero column is zero-width
is-deeply @W, [1,2,0], 'packing widths - zero column';
my $out2 = buf8.new(1, 0,16,  1, 2,229,  1, 4,6,  1, 5,166,);
is-deeply pack(@in, @W), $out2, '@W[1, 2, 0] pack';
is-deeply unpack($out2, @W).list, @in.list;
