use v6;

module PDF::IO::Util {

    #= resample a buffer as n-bit to m-bit unsigned integers
    proto sub resample( $, $, $ --> Buf) is export(:resample) {*};
    multi sub resample( $nums!, 8, 4)  { buf8.new: flat $nums.list.map: { ($_ +> 4, $_ +& 15) } }
    multi sub resample( $nums!, 4, 8)  { buf8.new: flat $nums.list.map: -> \hi, \lo { hi +< 4  +  lo } }
    multi sub resample( $nums!, 8, 16) { buf16.new: flat $nums.list.map: -> \hi, \lo { hi +< 8  +  lo } }
    multi sub resample( $nums!, 8, 32) { buf32.new: flat $nums.list.map: -> \b1, \b2, \b3, \b4 { b1 +< 24  +  b2 +< 16  +  b3 +< 8  +  b4 } }
    multi sub resample( $nums!, 16, 8) { buf8.new: flat $nums.list.map: { ($_ +> 8, $_) } }
    multi sub resample( $nums!, 32, 8) { buf8.new: flat $nums.list.map: { ($_ +> 24, $_ +> 16, $_ +> 8, $_) } }
    sub container(UInt $bits) {
        $bits <= 8 ?? uint8 !! ($bits > 16 ?? uint32 !! uint16)
    }
    multi sub resample( $nums! is copy, UInt $n!, UInt $ where $n) {
        $nums ~~ Buf
            ?? $nums
            !!  Buf[container($n)].new: $nums
    }

    sub get-bit($num, $bit) { $num +> ($bit) +& 1 }
    sub set-bit($bit) { 1 +< ($bit) }
    multi sub resample( $nums!, UInt $n!, UInt $m!) is default {
        warn "unoptimised $n => $m bit sampling";
        Buf[container($m)].new: flat gather {
            my int $m0 = 1;
            my int $sample = 0;

            for $nums.list -> $num is copy {
                for 1 .. $n -> int $n0 {

                    $sample += set-bit( $m - $m0)
                        if get-bit( $num, $n - $n0);

                    if ++$m0 > $m {
                        take $sample;
                        $sample = 0;
                        $m0 = 1;
                    }
                }
            }

            take $sample if $m0 > 1;
        }
    }
    #| variable resampling, e.g. to decode/encode:
    #|   obj 123 0 << /Type /XRef /W [1, 3, 1]
    multi sub resample( $nums!, 8, Array $W!)  {
        my uint $i = 0;
        my uint $j = 0;
        my uint32 @out;
        my $out-len = (+$nums * +$W) div $W.sum;
        my uint $w-len = +$W;

        @out[$out-len - 1] = 0
            if +$nums;

        while $i < +$nums {
            my uint32 $v = 0;
            my $n = $W[$j % $w-len];
            for 1 .. $n {
                $v +<= 8;
                $v += $nums[$i++];
            }
            @out[$j++] = $v;
        }
        my uint32 @shaped[+@out div +$W;$W] Z= @out;
        @shaped;
    }

    multi sub resample($shaped, Array $W!, 8)  {
        my uint8 @out;
        @out[$W.sum * +$shaped - 1] = 0
            if +$shaped;
        my int32 $j = -1;
        my uint32 @in = [ $shaped.values ];
        my uint32 $in-len = +@in;
        my uint $w-len = +$W;

        loop (my uint32 $i = 0; $i < $in-len;) {
            for 0 ..^ $w-len -> uint $wi {
                my uint32 $v = @in[$i++];
                my $n = $W[$wi];
                $j += $n;
                loop (my $k = 0; $k < $n; $k++) {
                    @out[$j - $k] = $v;
                    $v +>= 8;
                }
            }
         }
	 buf8.new: @out;
    }
}
