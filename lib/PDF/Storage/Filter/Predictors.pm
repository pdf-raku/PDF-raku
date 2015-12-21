use v6;

role PDF::Storage::Filter::Predictors {

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
                            UInt :$BitsPerComponent = 8, #| number of bits per color
        ) {
        my UInt $bit-mask = 2 ** $BitsPerComponent  -  1;
        my UInt @output;
        my UInt $ptr = 0;
        my Buf $nums = resample( $decoded, 8, $BitsPerComponent );

        while $ptr < +$nums {
            for 1 .. $Columns -> $i {
                for 1 .. $Colors {
                    my UInt $prev-color = $i > 1 ?? $nums[ $ptr - $Colors] !! 0;
                    my UInt $result = ($nums[ $ptr++ ] - $prev-color) +& $bit-mask;
                    @output.push: $result;
                }
            }
        }

	buf8.new: resample( @output, $BitsPerComponent, 8);
    }

    multi method prediction($encoded where Blob | Buf,
			    UInt :$Predictor! where { $_ >= 10 and $_ <= 15}, #| predictor function
			    UInt :$Columns = 1,          #| number of samples per row
			    UInt :$Colors = 1,           #| number of colors per sample
			    UInt :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my UInt $bytes-per-col = ($Colors * $BitsPerComponent  +  7) div 8;
        my UInt $bytes-per-row = $bytes-per-col * $Columns;
        my UInt $ptr = 0;
        my UInt $row = 0;
        my uint8 @output;

        while $ptr < +$encoded {

            $row++;
            @output.push: 4; # Paeth indicator

            for 1 .. $bytes-per-row -> $i {
                my UInt $left-byte = $i <= $bytes-per-col ?? 0 !! $encoded[$ptr - $bytes-per-col];
                my UInt $up-byte = $row > 1 ?? $encoded[$ptr - $bytes-per-row] !! 0;
                my UInt $up-left-byte = $row > 1 && $i > $bytes-per-col ?? $encoded[$ptr - $bytes-per-row -1] !! 0;

                my Int $p = $left-byte + $up-byte - $up-left-byte;

                my UInt $pa = abs($p - $left-byte);
                my UInt $pb = abs($p - $up-byte);
                my UInt $pc = abs($p - $up-left-byte);
                my UInt $nearest;

                if $pa <= $pb and $pa <= $pc {
                    $nearest = $left-byte;
                }
                elsif $pb <= $pc {
                    $nearest = $up-byte;
                }
                else {
                    $nearest = $up-left-byte
                }

                @output.push: ($encoded[$ptr++] - $nearest) % 256;
            }
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
        my Buf $nums = resample( $decoded, 8, $BitsPerComponent );
        my uint8 @output;

        while $ptr < +$nums {

            my @pixels = 0 xx $Colors;

            for 1  .. $Columns {

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

        my UInt $bytes-per-col = ($Colors * $BitsPerComponent  +  7) div 8;
        my UInt $bytes-per-row = $bytes-per-col * $Columns;
        my UInt $ptr = 0;
        my uint8 @output;

        my uint8 @up = 0 xx $bytes-per-row;

        while $ptr < +$decoded {
            # PNG prediction can vary from row to row
            my $filter-byte = $decoded[$ptr++];
            my @out;

            given $filter-byte {
                when 0 {
                    # None
                    @out.push: $decoded[$ptr++]
                        for 1 .. $bytes-per-row;
                }
                when 1 {
                    # Sub - 1
                    for 1 .. $bytes-per-row -> $i {
                        my UInt $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                        @out.push: ($decoded[$ptr++] + $left-byte) % 256;
                    }
                }
                when 2 {
                    # Up - 2
                    for 1 .. $bytes-per-row {
                        my UInt $up-byte = @up[ +@out ];
                        @out.push: ($decoded[$ptr++] + $up-byte) % 256;
                    }
                }
                when  3 {
                    # Average - 3
                    for 1 .. $bytes-per-row -> $i {
                        my UInt $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                        my UInt $up-byte = @up[ +@out ];
                        @out.push: ($decoded[$ptr++] + ( ($left-byte + $up-byte) div 2 )) % 256;
                    }
                }
                when 4 {
                    # Paeth - 4
                    for 1 .. $bytes-per-row -> $i {
                        my UInt $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                        my UInt $up-byte = @up[ +@out ];
                        my UInt $up-left-byte = $i <= $bytes-per-col ?? 0 !! @up[ +@out - $bytes-per-col];
                        my Int $p = $left-byte + $up-byte - $up-left-byte;

                        my UInt $pa = abs($p - $left-byte);
                        my UInt $pb = abs($p - $up-byte);
                        my UInt $pc = abs($p - $up-left-byte);
                        my UInt $nearest;

                        if $pa <= $pb and $pa <= $pc {
                            $nearest = $left-byte;
                        }
                        elsif $pb <= $pc {
                            $nearest = $up-byte;
                        }
                        else {
                            $nearest = $up-left-byte
                        }

                        @out.push: ($decoded[$ptr++] + $nearest) % 256;
                    }
                }
                default {
                    die "bad predictor byte: $_";
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
