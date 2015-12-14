use v6;

module PDF::Storage::Util {

    #= resample a buffer as n-bit to m-bit unsigned integers
    proto sub resample( $, $, $ --> Array) is export(:resample) {*};
    multi sub resample( $nums!, 8, 4)  { flat $nums.list.map: { ($_ +> 4, $_ +& 15) } }
    multi sub resample( $nums!, 4, 8)  { flat $nums.list.map: -> $hi, $lo { $hi +< 4  +  $lo } }
    multi sub resample( $nums!, 8, 16) { flat $nums.list.map: -> $hi, $lo { $hi +< 8  +  $lo } }
    multi sub resample( $nums!, 8, 32) { flat $nums.list.map: -> $b1, $b2, $b3, $b4 { $b1 +< 24  +  $b2 +< 16  +  $b3 +< 8  +  $b4 } }
    multi sub resample( $nums!, 16, 8) { flat $nums.list.map: { ($_ +> 8  +& 255, $_ +& 255) } }
    multi sub resample( $nums!, 32, 8) { flat $nums.list.map: { ($_ +> 24 +& 255, $_ +> 16 +& 255, $_ +> 8 +& 255, $_ +& 255) } }
    multi sub resample( $nums!, UInt $n!, UInt $m where $_ == $n) { $nums }
    multi sub resample( $nums!, UInt $n!, UInt $m!) is default {
        warn "unoptimised $n => $m bit sampling";
        flat gather {
            my Int $m0 = 1;
            my Int $sample = 0;

            sub get-bit($num, $bit) {
                $num +> ($bit) +& 1;
            }

            sub set-bit($bit) {
                1 +< ($bit);
            }

            for $nums.list -> $num is copy {
                for 1 .. $n -> $n0 {

                    my $in-bit = get-bit( $num, $n - $n0);
                    $sample += set-bit( $m - $m0)
                        if $in-bit;

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
        my Int $j = 0;
        my @samples;
        while $j < +$nums {
            my @sample = $W.keys.map: -> $i {
                my $s = 0;
                for 1 .. $W[$i] {
                    $s *= 256;
                    $s += $nums[$j++];
                }
                $s;
            }
            @samples.push: @sample;
        }
	@samples;
    }

    multi sub resample( $num-sets, Array $W!, 8)  {
	my uint8 @sample;
         for $num-sets.list -> Array $nums {
            my Int $i = 0;
            for $nums.list -> Int $num is copy {
                my uint8 @bytes;
                for 1 .. $W[$i++] {
                    @bytes.unshift: $num +& 255;
                    $num div= 256;
                }
                @sample.append: @bytes;
            }
        }
	flat @sample;
    }

}
