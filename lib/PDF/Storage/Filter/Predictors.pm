use v6;

role PDF::Storage::Filter::Predictors {

    my subset BPC of UInt where 1 | 2 | 4 | 8 | 16;

    use PDF::Storage::Util :resample;
    # post prediction functions as described in the PDF 1.7 spec, table 3.8
    multi method post-prediction($decoded where Blob | Buf, 
                                 UInt :$Predictor! where { $_ <= 1}, #| predictor function
        ) {
        $decoded; # noop
    }

    multi method prediction($decoded where Blob | Buf, 
                            UInt :$Predictor! where { $_ == 2}, #| predictor function
                            UInt :$Columns = 1,          #| number of samples per row
                            UInt :$Colors = 1,           #| number of colors per sample
                            BPC  :$BitsPerComponent = 8, #| number of bits per color
        ) {
        my UInt $bit-mask = 2 ** $BitsPerComponent  -  1;
        my UInt @output;
        my UInt $ptr = 0;
        my Buf $nums := resample( $decoded, 8, $BitsPerComponent );

        while $ptr < +$nums {
	    for 1 .. $Colors {
		@output.push: $nums[ $ptr++ ];
	    }
            for 2 .. $Columns -> $i {
                for 1 .. $Colors {
                    my UInt $prev-color = $nums[$ptr - $Colors];
                    my UInt $result = ($nums[ $ptr++ ] - $prev-color) +& $bit-mask;
                    @output.push: $result;
                }
            }
        }

	buf8.new: resample( @output, $BitsPerComponent, 8);
    }

    multi method prediction($encoded where Blob | Buf,
			    UInt :$Predictor! where { 10 <= $_ <= 15}, #| predictor function
			    UInt :$Columns = 1,          #| number of samples per row
			    UInt :$Colors = 1,           #| number of colors per sample
			    BPC  :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my UInt $bytes-per-col = ceiling($Colors * $BitsPerComponent / 8);
        my UInt $bytes-per-row = $bytes-per-col * $Columns;
        my UInt $ptr = 0;
        my UInt $row = 0;
        my uint8 @output;

        while $ptr < +$encoded {

            @output.push: 4; # Paeth indicator

            for 1 .. $bytes-per-row -> $i {
                my uint8 $left-byte = $i <= $bytes-per-col ?? 0 !! $encoded[$ptr - $bytes-per-col];
                my uint8 $up-byte = $row ?? $encoded[$ptr - $bytes-per-row] !! 0;
                my uint8 $up-left-byte = $row && $i > $bytes-per-col ?? $encoded[$ptr - $bytes-per-row - $bytes-per-col] !! 0;

                my uint8 $p = $left-byte + $up-byte - $up-left-byte;

                my uint8 $pa = abs($p - $left-byte);
                my uint8 $pb = abs($p - $up-byte);
                my uint8 $pc = abs($p - $up-left-byte);
                my uint8 $nearest;

                if $pa <= $pb and $pa <= $pc {
                    $nearest = $left-byte;
                }
                elsif $pb <= $pc {
                    $nearest = $up-byte;
                }
                else {
                    $nearest = $up-left-byte
                }

                @output.push: ($encoded[$ptr++] - $nearest);
            }

            $row++;
        }

        buf8.new: @output;
    }

    # prediction filters, see PDF 1.7 sepc table 3.8
    multi method prediction($encoded where Blob | Buf,
			    UInt :$Predictor=1, #| predictor function
        ) {
        die "Unknown Flate/LZW predictor function: $Predictor"
            unless $Predictor == 1;
        $encoded;
    }

    # prediction filters, see PDF 1.7 sepc table 3.8
    multi method post-prediction($decoded where Blob | Buf, 
                                 UInt :$Predictor! where { $_ == 2}, #| predictor function
                                 UInt :$Columns = 1,          #| number of samples per row
                                 UInt :$Colors = 1,           #| number of colors per sample
                                 UInt :$BitsPerComponent = 8, #| number of bits per color
        ) {
        my UInt $bit-mask = 2 ** $BitsPerComponent  -  1;
        my UInt $ptr = 0;
        my Buf $nums := resample( $decoded, 8, $BitsPerComponent );
        my UInt @output;

        while $ptr < +$nums {

            my @pixels = 0 xx $Colors;

            for 1 .. $Columns {

                for 0 ..^ $Colors {
                    @pixels[$_] = (@pixels[$_] + $nums[ $ptr++ ]) +& $bit-mask;
                }

                @output.append: @pixels;
            }
        }

        buf8.new: resample( @output, $BitsPerComponent, 8);
    }

    multi method post-prediction($decoded,  #| input stream
                                 UInt :$Predictor! where { 10 <= $_ <= 15}, #| predictor function
                                 UInt :$Columns = 1,          #| number of samples per row
                                 UInt :$Colors = 1,           #| number of colors per sample
                                 UInt :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my UInt $bytes-per-col = ceiling($Colors * $BitsPerComponent / 8);
        my UInt $bytes-per-row = $bytes-per-col * $Columns;
        my UInt $ptr = 0;
        my uint8 @output;

        my uint8 @up = 0 xx $bytes-per-row;

        while $ptr < +$decoded {
            # PNG prediction can vary from row to row
            my uint8 $tag = $decoded[$ptr++];
            my uint8 @out;

            given $tag {
                when 0 {
                    # None
                    @out.push: $decoded[$ptr++]
                        for 1 .. $bytes-per-row;
                }
                when 1 {
                    # Sub - 1
                    for 1 .. $bytes-per-row -> $i {
                        my UInt $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                        @out.push: ($decoded[$ptr++] + $left-byte);
                    }
                }
                when 2 {
                    # Up - 2
                    for 1 .. $bytes-per-row {
                        my UInt $up-byte = @up[ +@out ];
                        @out.push: ($decoded[$ptr++] + $up-byte);
                    }
                }
                when  3 {
                    # Average - 3
                    for 1 .. $bytes-per-row -> $i {
                        my UInt $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                        my UInt $up-byte = @up[ +@out ];
                        @out.push: ($decoded[$ptr++] + ( ($left-byte + $up-byte) div 2 ));
                    }
                }
                when 4 {
                    # Paeth - 4
                    for 1 .. $bytes-per-row -> $i {
                        my uint8 $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                        my uint8 $up-byte = @up[ +@out ];
                        my uint8 $up-left-byte = $i <= $bytes-per-col ?? 0 !! @up[ +@out - $bytes-per-col];
                        my uint8 $p = $left-byte + $up-byte - $up-left-byte;

                        my uint8 $pa = abs($p - $left-byte);
                        my uint8 $pb = abs($p - $up-byte);
                        my uint8 $pc = abs($p - $up-left-byte);
                        my uint8 $nearest;

                        if $pa <= $pb and $pa <= $pc {
                            $nearest = $left-byte;
                        }
                        elsif $pb <= $pc {
                            $nearest = $up-byte;
                        }
                        else {
                            $nearest = $up-left-byte
                        }

                        @out.push: ($decoded[$ptr++] + $nearest);
                    }
                }
                default {
                    die "bad PNG predictor tag: $_";
                }
            }

            @up = @out;
            @output.append: @out;
        }

        buf8.new: @output;
    }

    multi method post-prediction($decoded, UInt :$Predictor = 1, ) is default {
        die "Unknown Flate/LZW predictor function: $Predictor"
            unless $Predictor == 1;
        $decoded;
    }

}
