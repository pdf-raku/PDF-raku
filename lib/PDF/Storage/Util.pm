use v6;

module PDF::Storage::Util {

    #= resample a buffer as n-bit to m-bit unsigned integers
    proto sub resample( $, $, $ --> Array) is export(:resample) {*};
    multi sub resample( $nums!, 8, 4)  { $nums.list.map: { ($_ +> 4, $_ +& 15).flat } }
    multi sub resample( $nums!, 4, 8)  { $nums.list.map: -> $hi, $lo { $hi +< 4  +  $lo } }
    multi sub resample( $nums!, 8, 16) { $nums.list.map: -> $hi, $lo { $hi +< 8  +  $lo } }
    multi sub resample( $nums!, 8, 32) { $nums.list.map: -> $b1, $b2, $b3, $b4 { $b1 +< 24  +  $b2 +< 16  +  $b3 +< 8  +  $b4 } }
    multi sub resample( $nums!, 16, 8) { $nums.list.map: { ($_ +> 8, $_ +& 255).flat } }
    multi sub resample( $nums!, 32, 8) { $nums.list.map: { ($_ +> 24, $_ +> 16 +& 255, $_ +> 8 +& 255, $_ +& 255).flat } }
    multi sub resample( $nums!, $n!, $m where $_ == $n) { $nums }
    multi sub resample( $nums!, $n!, $m!) is default {
        warn "unoptimised $n => $m bit sampling";
        gather {
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
            @samples.push: @sample.item;
        }
        @samples;
    }

    multi sub resample( $num-sets, Array $W!, 8)  {
        $num-sets.list.map: -> Array $nums {
            my Int $i = 0;
            $nums.list.map: -> Int $num is copy {
                my @bytes;
                for 1 .. $W[$i++] {
                    @bytes.unshift: $num +& 255;
                    $num div= 256;
                }
                @bytes;
            }
        }
    }

}
