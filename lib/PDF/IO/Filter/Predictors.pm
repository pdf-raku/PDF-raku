use v6;

class PDF::IO::Filter::Predictors {

    my subset BPC of UInt where 1 | 2 | 4 | 8 | 16;
    my subset Predictor of Int where 1|2|10..15;

    use PDF::IO::Util :resample;
    # post prediction functions as described in the PDF 1.7 spec, table 3.8

    multi method encode($buf where Blob | Buf, 
                        Predictor :$Predictor! where 2, #| predictor function
                        UInt :$Columns = 1,          #| number of samples per row
                        UInt :$Colors = 1,           #| number of colors per sample
                        BPC  :$BitsPerComponent = 8, #| number of bits per color
        ) {
        my uint $bit-mask = 2 ** $BitsPerComponent  -  1;
        my \nums := resample( $buf, 8, $BitsPerComponent );
        my uint $len = +nums;
        my uint @output;
        my uint $ptr = 0;

        while $ptr < $len {
	    for 1 .. $Colors {
		@output.push: nums[ $ptr++ ];
	    }
            for 2 .. $Columns {
                for 1 .. $Colors {
                    my \prev-color = nums[$ptr - $Colors];
                    my int $result = (nums[ $ptr++ ] - prev-color) +& $bit-mask;
                    @output.push: $result;
                }
            }
        }

	buf8.new: resample( @output, $BitsPerComponent, 8);
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
        $buf = resample($buf, 8, $bpc)
            unless $bpc == 8;

        my uint $bit-mask = 2 ** $bpc  -  1;
        my uint $row-size = $colors * $Columns;
        my uint $ptr = 0;
        my uint $row = 0;
        my uint8 @out;
        my uint $tag = min($Predictor - 10, 4);
        my int $n = 0;
        my int $len = +$buf;

         my $padding = do {
            my $bits-per-row = $row-size * $bpc;
            my $bit-padding = -$bits-per-row % 8;
            $bit-padding div $bpc;
        }

        while $ptr < $len {

            @out[$n++] = $tag;

            given $tag {
                when 0 { # None
                    @out[$n++] = $buf[$ptr++]
                        for 1 .. $row-size;
                }
                when 1 { # Left
                    @out[$n++] = $buf[$ptr++] for 1 .. $colors;
                    for $colors ^.. $row-size {
                        my \left-val = $buf[$ptr - $colors];
                        @out[$n++] = ($buf[$ptr++] - left-val) +& $bit-mask;
                    }
                }
                when 2 { # Up
                    for 1 .. $row-size {
                        my \up-val = $row ?? $buf[$ptr - $row-size] !! 0;
                        @out[$n++] = ($buf[$ptr++] - up-val) +& $bit-mask;
                    }
                }
                when 3 { # Average
                   for 1 .. $row-size -> \i {
                        my \left-val = i <= $colors ?? 0 !! $buf[$ptr - $colors];
                        my \up-val = $row ?? $buf[$ptr - $row-size] !! 0;
                        @out[$n++] = ($buf[$ptr++] - ( (left-val + up-val) div 2 )) +& $bit-mask;
                   }
                }
                when 4 { # Paeth
                   for 1 .. $row-size -> \i {
                       my \left-val = i <= $colors ?? 0 !! $buf[$ptr - $colors];
                       my \up-val = $row ?? $buf[$ptr - $row-size] !! 0;
                       my \up-left-val = $row && i > $colors ?? $buf[$ptr - $row-size - $colors] !! 0;

                       my int $p = left-val + up-val - up-left-val;
                       my int $pa = abs($p - left-val);
                       my int $pb = abs($p - up-val);
                       my int $pc = abs($p - up-left-val);
                       my \nearest = do if $pa <= $pb and $pa <= $pc {
                           left-val;
                       }
                       elsif $pb <= $pc {
                           up-val;
                       }
                       else {
                           up-left-val
                       }
                       @out[$n++] = ($buf[$ptr++] - nearest) +& $bit-mask;
                   }
                }
            }

            $row++;
            $ptr++ for 0 ..^ $padding;
         }

       @out = resample($@out, $bpc, 8)
            unless $bpc == 8;
        buf8.new: @out;
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
        my \nums = resample( $buf, 8, $BitsPerComponent );
        my int $len = +nums;
        my uint $ptr = 0;
        my uint @output;

        while $ptr < $len {
            my uint @pixels = 0 xx $Colors;

            for 1 .. $Columns {

                for 0 ..^ $Colors {
                    @pixels[$_] = (@pixels[$_] + nums[ $ptr++ ]) +& $bit-mask;
                }

                @output.append: @pixels;
            }
        }

        buf8.new: resample( @output, $BitsPerComponent, 8);
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
        $buf = resample($buf, 8, $bpc)
            unless $bpc == 8;

        my uint $bit-mask = 2 ** $bpc  -  1;
        my uint $row-size = $colors * $Columns;
        my uint $ptr = 0;
        my uint $len = +$buf;
        my uint8 @output;
        my uint8 @up = 0 xx $row-size;

        my $padding = do {
            my $bits-per-row = $row-size * $bpc;
            my $bit-padding = -$bits-per-row % 8;
            $bit-padding div $bpc;
        }

        while $ptr < $len {
            # PNG prediction can vary from row to row
            my UInt $tag = $buf[$ptr++];
            my uint8 @out;
            my int $n = 0;
            $tag -= 10 if 10 <= $tag <= 14; 

            given $tag {
                when 0 { # None
                    @out[$n++] = $buf[$ptr++]
                        for 1 .. $row-size;
                }
                when 1 { # Sub
                    @out[$n++] = $buf[$ptr++] for 1 .. $colors;
                    for $colors ^.. $row-size {
                        my \left-val = @out[$n - $colors];
                        @out[$n++] = ($buf[$ptr++] + left-val) +& $bit-mask;
                    }
                }
                when 2 { # Up
                    for 1 .. $row-size {
                        my \up-val = @up[$n];
                        @out[$n++] = ($buf[$ptr++] + up-val) +& $bit-mask;
                    }
                }
                when  3 { # Average
                    for 1 .. $row-size -> \i {
                        my \left-val = i <= $colors ?? 0 !! @out[$n - $colors];
                        my \up-val = @up[$n];
                        @out[$n++] = ($buf[$ptr++] + ( (left-val + up-val) div 2 )) +& $bit-mask;
                    }
                }
                when 4 { # Paeth
                    for 1 .. $row-size -> \i {
                        my \left-val = i <= $colors ?? 0 !! @out[$n - $colors];
                        my \up-left-val = i <= $colors ?? 0 !! @up[$n - $colors];
                        my \up-val = @up[$n];

                        my int $p = left-val + up-val - up-left-val;
                        my int $pa = abs($p - left-val);
                        my int $pb = abs($p - up-val);
                        my int $pc = abs($p - up-left-val);
                        my \nearest = do if $pa <= $pb and $pa <= $pc {
                            left-val;
                        }
                        elsif $pb <= $pc {
                            up-val;
                        }
                        else {
                            up-left-val
                        }

                        @out[$n++] = ($buf[$ptr++] + nearest) +& $bit-mask;
                    }
                }
                default {
                    die "bad PNG predictor tag: $_";
                }
            }

            @up := @out;
            @output.append: @out;
            $ptr++ for 0 ..^ $padding;
        }

        @output = resample($@output, $bpc, 8)
            unless $bpc == 8;

        buf8.new: @output;
    }

    multi method decode($buf, Predictor :$Predictor where {1} = 1 ) is default {
        $buf;
    }

}
