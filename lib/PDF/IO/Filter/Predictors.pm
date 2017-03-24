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

    multi method encode($buf where Blob | Buf,
			Predictor :$Predictor! where { 10 <= $_ <= 15}, #| predictor function
			UInt :$Columns = 1,          #| number of samples per row
			UInt :$Colors = 1,           #| number of colors per sample
			BPC  :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my uint $bytes-per-col = ceiling($Colors * $BitsPerComponent / 8);
        my uint $bytes-per-row = $bytes-per-col * $Columns;
        my uint $ptr = 0;
        my uint $row = 0;
        my uint8 @out;
        my uint $tag = min($Predictor - 10, 4);
        my int $n = 0;
        my int $len = +$buf;

        while $ptr < $len {

            @out[$n++] = $tag;

            given $tag {
                when 0 { # None
                    @out[$n++] = $buf[$ptr++]
                        for 1 .. $bytes-per-row;
                }
                when 1 { # Left
                    @out[$n++] = $buf[$ptr++] for 1 .. $bytes-per-col;
                    for $bytes-per-col ^.. $bytes-per-row {
                        my \left-byte = $buf[$ptr - $bytes-per-col];
                        @out[$n++] = $buf[$ptr++] - left-byte;
                    }
                }
                when 2 { # Up
                    for 1 .. $bytes-per-row {
                        my \up-byte = $row ?? $buf[$ptr - $bytes-per-row] !! 0;
                        @out[$n++] = $buf[$ptr++] - up-byte;
                    }
                }
                when 3 { # Average
                   for 1 .. $bytes-per-row -> \i {
                        my \left-byte = i <= $bytes-per-col ?? 0 !! $buf[$ptr - $bytes-per-col];
                        my \up-byte = $row ?? $buf[$ptr - $bytes-per-row] !! 0;
                        @out[$n++] = $buf[$ptr++] - ( (left-byte + up-byte) div 2 );
                   }
                }
                when 4 { # Paeth
                   for 1 .. $bytes-per-row -> \i {
                       my \left-byte = i <= $bytes-per-col ?? 0 !! $buf[$ptr - $bytes-per-col];
                       my \up-byte = $row ?? $buf[$ptr - $bytes-per-row] !! 0;
                       my \up-left-byte = $row && i > $bytes-per-col ?? $buf[$ptr - $bytes-per-row - $bytes-per-col] !! 0;

                       my int $p = left-byte + up-byte - up-left-byte;
                       my int $pa = abs($p - left-byte);
                       my int $pb = abs($p - up-byte);
                       my int $pc = abs($p - up-left-byte);
                       my \nearest = do if $pa <= $pb and $pa <= $pc {
                           left-byte;
                       }
                       elsif $pb <= $pc {
                           up-byte;
                       }
                       else {
                           up-left-byte
                       }
                       @out[$n++] = $buf[$ptr++] - nearest;
                   }
                }
            }

            $row++;
        }

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

    multi method decode($buf where Blob | Buf,  #| input stream
                        Predictor :$Predictor! where { 10 <= $_ <= 15}, #| predictor function
                        UInt :$Columns = 1,          #| number of samples per row
                        UInt :$Colors = 1,           #| number of colors per sample
                        UInt :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my uint $bytes-per-col = ceiling($Colors * $BitsPerComponent / 8);
        my uint $bytes-per-row = $bytes-per-col * $Columns;
        my uint $len = +$buf;
        my uint $ptr = 0;
        my uint8 @output;

        my uint8 @up = 0 xx $bytes-per-row;

        while $ptr < $len {
            # PNG prediction can vary from row to row
            my UInt $tag = $buf[$ptr++];
            my uint8 @out;
            my int $n = 0;
            $tag -= 10 if 10 <= $tag <= 14; 

            given $tag {
                when 0 { # None
                    @out[$n++] = $buf[$ptr++]
                        for 1 .. $bytes-per-row;
                }
                when 1 { # Sub
                    @out[$n++] = $buf[$ptr++] for 1 .. $bytes-per-col;
                    for $bytes-per-col ^.. $bytes-per-row {
                        my \left-byte = @out[$n - $bytes-per-col];
                        @out[$n++] = $buf[$ptr++] + left-byte;
                    }
                }
                when 2 { # Up
                    for 1 .. $bytes-per-row {
                        my \up-byte = @up[$n];
                        @out[$n++] = $buf[$ptr++] + up-byte;
                    }
                }
                when  3 { # Average
                    for 1 .. $bytes-per-row -> \i {
                        my \left-byte = i <= $bytes-per-col ?? 0 !! @out[$n - $bytes-per-col];
                        my \up-byte = @up[$n];
                        @out[$n++] = $buf[$ptr++] + ( (left-byte + up-byte) div 2 );
                    }
                }
                when 4 { # Paeth
                    for 1 .. $bytes-per-row -> \i {
                        my \left-byte = i <= $bytes-per-col ?? 0 !! @out[$n - $bytes-per-col];
                        my \up-left-byte = i <= $bytes-per-col ?? 0 !! @up[$n - $bytes-per-col];
                        my \up-byte = @up[$n];

                        my int $p = left-byte + up-byte - up-left-byte;
                        my int $pa = abs($p - left-byte);
                        my int $pb = abs($p - up-byte);
                        my int $pc = abs($p - up-left-byte);
                        my \nearest = do if $pa <= $pb and $pa <= $pc {
                            left-byte;
                        }
                        elsif $pb <= $pc {
                            up-byte;
                        }
                        else {
                            up-left-byte
                        }

                        @out[$n++] = $buf[$ptr++] + nearest;
                    }
                }
                default {
                    die "bad PNG predictor tag: $_";
                }
            }

            @up := @out;
            @output.append: @out;
        }

        buf8.new: @output;
    }

    multi method decode($buf, Predictor :$Predictor where {1} = 1 ) is default {
        $buf;
    }

}
