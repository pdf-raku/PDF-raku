use v6;

class PDF::IO::Filter::Predictors {

    my subset BPC of UInt where 1 | 2 | 4 | 8 | 16 | 32;
    my subset Predictor of Int where 1|2|10..15;

    use PDF::IO::Util :pack;
    # post prediction functions as described in the PDF 1.7 spec, table 3.8

    multi method encode($buf where Blob | Buf, 
                        Predictor :$Predictor! where 2, #| predictor function
                        UInt :$Columns = 1,          #| number of samples per row
                        UInt :$Colors = 1,           #| number of colors per sample
                        BPC  :$BitsPerComponent = 8, #| number of bits per color
        ) {
        my uint $bit-mask = 2 ** $BitsPerComponent  -  1;
        my \nums := unpack( $buf, $BitsPerComponent );
        my uint $len = +nums;
        my uint @output;
        my uint $idx = 0;

        while $idx < $len {
	    for 1 .. $Colors {
		@output.push: nums[ $idx++ ];
	    }
            for 2 .. $Columns {
                for 1 .. $Colors {
                    my \prev-color = nums[$idx - $Colors];
                    my int $result = (nums[ $idx++ ] - prev-color) +& $bit-mask;
                    @output.push: $result;
                }
            }
        }

	pack( @output, $BitsPerComponent);
    }

    multi method encode($buf is copy where Blob | Buf,
			Predictor :$Predictor! where { 10 <= $_ <= 15}, #| predictor function
			UInt :$Columns = 1,          #| number of samples per row
			UInt :$Colors = 1,           #| number of colors per sample
			BPC  :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my uint $bpc = $BitsPerComponent;
        my uint $colors = $Colors;
        if $bpc > 8 {
            $colors *= $bpc div 8;
            $bpc = 8;
        }
        $buf = unpack($buf, $bpc);

        my uint $bit-mask = 2 ** $bpc  -  1;
        my uint $row-size = $colors * $Columns;
        my uint $idx = 0;
        my uint8 @out;
        my uint $tag = min($Predictor - 10, 4);
        my int $n = 0;
        my int $len = +$buf;

        my $padding = do {
            my $bits-per-row = $row-size * $bpc;
            my $bit-padding = -$bits-per-row % 8;
            $bit-padding div $bpc;
        }

        my $rows = $len div $row-size;
        # preallocate, allowing room for per-row data + tag + padding
        @out[$rows * ($row-size + $padding + 1) - 1] = 0
            if $rows;

        loop (my uint $row = 0; $row < $rows; $row++) {
            @out[$n++] = $tag;

            given $tag {
                when 0 { # None
                    @out[$n++] = $buf[$idx++]
                        for 1 .. $row-size;
                }
                when 1 { # Left
                    @out[$n++] = $buf[$idx++] for 1 .. $colors;
                    for $colors ^.. $row-size {
                        my \left-val = $buf[$idx - $colors];
                        @out[$n++] = ($buf[$idx++] - left-val) +& $bit-mask;
                    }
                }
                when 2 { # Up
                    for 1 .. $row-size {
                        my \up-val = $row ?? $buf[$idx - $row-size] !! 0;
                        @out[$n++] = ($buf[$idx++] - up-val) +& $bit-mask;
                    }
                }
                when 3 { # Average
                   for 1 .. $row-size -> int $i {
                        my \left-val = $i <= $colors ?? 0 !! $buf[$idx - $colors];
                        my \up-val = $row ?? $buf[$idx - $row-size] !! 0;
                        @out[$n++] = ($buf[$idx++] - ( (left-val + up-val) div 2 )) +& $bit-mask;
                   }
                }
                when 4 { # Paeth
                   for 1 .. $row-size -> int $i {
                       my \left-val = $i <= $colors ?? 0 !! $buf[$idx - $colors];
                       my \up-val = $row ?? $buf[$idx - $row-size] !! 0;
                       my \up-left-val = $row && $i > $colors ?? $buf[$idx - $row-size - $colors] !! 0;

                       my int $p = left-val + up-val - up-left-val;
                       my int $pa = abs($p - left-val);
                       my int $pb = abs($p - up-val);
                       my int $pc = abs($p - up-left-val);
                       my \nearest = $pa <= $pb && $pa <= $pc 
                           ?? left-val
                           !! ($pb <= $pc ?? up-val !! up-left-val);
                       @out[$n++] = ($buf[$idx++] - nearest) +& $bit-mask;
                   }
                }
            }

            @out[$n++] = 0
                for 0 ..^ $padding;
         }

        pack(@out, $bpc)
    }

    # prediction filters, see PDF 1.7 spec table 3.8
    multi method encode($buf where Blob | Buf,
			Predictor :$Predictor where {1} = 1 #| predictor function
        ) {
        $buf;
    }

    # prediction filters, see PDF 1.7 spec table 3.8
    multi method decode($buf where Blob | Buf, 
                        Predictor :$Predictor! where 2, #| predictor function
                        UInt :$Columns = 1,          #| number of samples per row
                        UInt :$Colors = 1,           #| number of colors per sample
                        UInt :$BitsPerComponent = 8, #| number of bits per color
        ) {
        my uint $bit-mask = 2 ** $BitsPerComponent  -  1;
        my \nums = unpack( $buf, $BitsPerComponent );
        my int $len = +nums;
        my uint $idx = 0;
        my uint @output;

        while $idx < $len {
            my uint @pixels = 0 xx $Colors;

            for 1 .. $Columns {

                for 0 ..^ $Colors {
                    @pixels[$_] = (@pixels[$_] + nums[ $idx++ ]) +& $bit-mask;
                }

                @output.append: @pixels;
            }
        }

        pack( @output, $BitsPerComponent);
    }

    multi method decode($buf is copy where Blob | Buf,  #| input stream
                        Predictor :$Predictor! where { 10 <= $_ <= 15}, #| predictor function
                        UInt :$Columns = 1,          #| number of samples per row
                        UInt :$Colors = 1,           #| number of colors per sample
                        UInt :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my uint $bpc = $BitsPerComponent;
        my uint $colors = $Colors;
        if $bpc > 8 {
            $colors *= $bpc div 8;
            $bpc = 8;
        }
        $buf = unpack($buf, $bpc);

        my uint $bit-mask = 2 ** $bpc  -  1;
        my uint $row-size = $colors * $Columns;
        my uint $idx = 0;
        my uint $len = +$buf;
        my uint8 @out;
        my int $n = 0;

        my $padding = do {
            my $bits-per-row = $row-size * $bpc;
            my $bit-padding = -$bits-per-row % 8;
            $bit-padding div $bpc;
        }

        # each input row also has a tag plus any padding
        my $rows = $len div ($row-size + $padding + 1);
        # preallocate
        @out[$rows * $row-size - 1] = 0
            if $rows;

        loop (my uint $row = 0; $row < $rows; $row++) {
            # PNG prediction can vary from row to row
            my UInt $tag = $buf[$idx++];
            $tag -= 10 if 10 <= $tag <= 14; 

            given $tag {
                when 0 { # None
                    @out[$n++] = $buf[$idx++]
                        for 1 .. $row-size;
                }
                when 1 { # Left
                    @out[$n++] = $buf[$idx++] for 0 ..^ $colors;
                    for $colors ^.. $row-size {
                        my \left-val = @out[$n - $colors];
                        @out[$n++] = ($buf[$idx++] + left-val) +& $bit-mask;
                    }
                }
                when 2 { # Up
                    for 0 ..^ $row-size {
                        my \up-val = $row ?? @out[$n - $row-size] !! 0;
                        @out[$n++] = ($buf[$idx++] + up-val) +& $bit-mask;
                    }
                }
                when  3 { # Average
                    for 0 ..^ $row-size -> int $i {
                        my \left-val = $i < $colors ?? 0 !! @out[$n - $colors];
                        my \up-val = $row ?? @out[$n - $row-size] !! 0;
                        @out[$n++] = ($buf[$idx++] + ( (left-val + up-val) div 2 )) +& $bit-mask;
                    }
                }
                when 4 { # Paeth
                    for 0 ..^ $row-size -> \i {
                        my \left-val = i < $colors ?? 0 !! @out[$n - $colors];
                        my \up-val = $row ?? @out[$n - $row-size] !! 0;
                        my \up-left-val = $row && i >= $colors ?? @out[$n - $colors - $row-size] !! 0;

                        my int $p = left-val + up-val - up-left-val;
                        my int $pa = abs($p - left-val);
                        my int $pb = abs($p - up-val);
                        my int $pc = abs($p - up-left-val);
                        my \nearest = $pa <= $pb && $pa <= $pc
                           ?? left-val
                           !! ($pb <= $pc ?? up-val !! up-left-val);

                        @out[$n++] = ($buf[$idx++] + nearest) +& $bit-mask;
                    }
                }
                default {
                    die "bad PNG predictor tag: $_";
                }
            }

            $idx += $padding;
        }

        pack(@out, $bpc);
    }

    multi method decode($buf, Predictor :$Predictor where {1} = 1 ) is default {
        $buf;
    }

}
