use v6;

module PDF::Basic::Util;

#= resample a buffer as n-bit to m-bit unsigned integers
proto sub resample($,$,$) is export(:resample) {*};
multi sub resample( $nums, 8, 4)  { $nums.list.map: { ($_ +> 4, $_ +& 15).flat } }
multi sub resample( $nums, 4, 8)  { $nums.list.map: -> $hi, $lo { $hi * 16 + $lo } }
multi sub resample( $nums, 8, 16) {
    $nums.list.map: -> $hi, $lo {
        $hi +< 8  + $lo;
    } }
multi sub resample( $nums, 16, 8) { $nums.list.map: { ($_ +> 8, $_ +& 255).flat } }
multi sub resample( $nums, $n, $m where $_ == $n) { $nums }
multi sub resample( $nums, $n, $m) is default {
    warn "unoptimised $n => $m bit sampling";
    gather {
        my $m0 = 1;
        my $sample = 0;

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
