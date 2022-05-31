use v6;

module PDF::IO::Util {

    use PDF::COS;

    our sub have-pdf-native(Version :$min-version = v0.0.1) {
        try ((require ::('PDF::Native')) !=== Nil)
        && ::('PDF::Native').version >= $min-version;
    }

    #| loads a faster alternative
    our sub native-speed-up(Str $module-name, Str $sub-name) {
        try {
            require ::($module-name);
            ::($module-name)::('&'~$sub-name);
        }
    }
    #= network (big-endian) ordered byte packing and unpacking
    proto sub unpack-be( $, $ --> Blob) is export(:pack-be) {*};
    proto sub pack-be( $, $ --> Blob) is export(:pack-be) {*};
    my constant Packer = 'PDF::Native::Buf';
    our &pack is export(:pack) = INIT native-speed-up(Packer, 'pack') // &pack-be;
    our &unpack is export(:pack) = INIT native-speed-up(Packer, 'unpack') // &unpack-be;
    multi sub unpack-be( $nums!, 4)  { blob8.new: flat $nums.list.map: { ($_ +> 4, $_ +& 15) } }
    multi sub unpack-be( $nums!, 16) { blob16.new: flat $nums.list.map: -> \hi, \lo { hi +< 8  +  lo } }
    multi sub unpack-be( $nums!, 32) { blob32.new: flat $nums.list.map: -> \b1, \b2, \b3, \b4 { b1 +< 24  +  b2 +< 16  +  b3 +< 8  +  b4 } }
    multi sub unpack-be( $nums!, $n) { resample( $nums, 8, $n); }
    multi sub pack-be( $nums!, 4)  { blob8.new: flat $nums.list.map: -> \hi, \lo { hi +< 4  +  lo } }
    multi sub pack-be( $nums!, 16) { blob8.new: flat $nums.list.map: { ($_ +> 8, $_) } }
    multi sub pack-be( $nums!, 32) { blob8.new: flat $nums.list.map: { ($_ +> 24, $_ +> 16, $_ +> 8, $_) } }
    multi sub pack-be( $nums!, UInt $n) { resample( $nums, $n, 8); }

    #= little-endian ordered packing
    proto sub pack-le( $, $ --> Blob) is export(:pack,:pack-be) {*};
    multi sub pack-le( $nums!, 32) { blob8.new: flat $nums.list.map: { ($_, $_ +> 8, $_ +> 16, $_ +> 24) } }

    sub of(UInt $bits) {
        $bits <= 8 ?? uint8 !! ($bits > 16 ?? uint32 !! uint16)
    }
    multi sub resample( $nums! is copy, UInt $bits!, UInt $ where $bits) {
        $nums ~~ Blob
            ?? $nums
            !! Blob[ of($bits) ].new: $nums
    }

    sub get-bit($num, $bit) { $num +> ($bit) +& 1 }
    sub set-bit($bit) { 1 +< ($bit) }
    multi sub resample( $nums!, UInt $n!, UInt $m!) {
        warn "unoptimised $n => $m bit sampling";
        Blob[ of($m) ].new: flat gather {
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
    #|   obj 123 0 << /Type /XRef /W [1, 3, 1] ... >>
    multi sub unpack-be( $nums!, Array $W!)  {
        my uint $w-len = +$W;
        my $out-len = (+$nums * $w-len) div $W.sum;
        my uint32 @out[$out-len div $w-len; $w-len];
        my uint $i = 0;

        loop (my uint $j = 0; $j < $out-len;) {
            my uint32 $v = 0;
            my $k = $j % $w-len;
            for 1 .. $W[$k] {
                $v +<= 8;
                $v += $nums[$i++];
            }
            @out[$j++ div $w-len; $k] = $v;
        }
        @out;
    }

    multi sub pack-be(array $shaped, Array $W!)  {
        my buf8 $out .= allocate($W.sum * +$shaped);
        my blob32 $in .= new: $shaped;
        my uint32 $in-len = +$in;
        my int32 $j = -1;
        my uint $w-len = +$W;

        loop (my uint32 $i = 0; $i < $in-len;) {
            for ^$w-len -> uint $wi {
                my uint32 $v = $in[$i++];
                my $n = $W[$wi];
                $j += $n;
                loop (my $k = 0; $k < $n; $k++) {
                    $out[$j - $k] = $v;
                    $v +>= 8;
                }
            }
         }
	 $out;
    }
}
