use v6;

role PDF::Storage::Filter::Predictors {

    use PDF::Storage::Util :resample;
    # post prediction functions as described in the PDF 1.7 spec, table 3.8
    multi method post-prediction($decoded where Blob | Buf, 
                                 Int :$Predictor! where { $_ <= 1}, #| predictor function
        ) {
        $decoded; # noop
    }

    multi method prediction($decoded where Blob | Buf, 
                            Int :$Predictor! where { $_ == 2}, #| predictor function
                            Int :$Columns = 1,          #| number of samples per row
                            Int :$Colors = 1,           #| number of colors per sample
                            Int :$BitsPerComponent = 8, #| number of bits per color
        ) {
        my Int $bit-mask = 2 ** $BitsPerComponent  -  1;
        my @output;
        my Int $ptr = 0;
        my Buf $nums = resample( $decoded, 8, $BitsPerComponent );

        while $ptr < +$nums {
            for 1 .. $Columns -> $i {
                for 1 .. $Colors {
                    my Int $prev-color = $i > 1 ?? $nums[ $ptr - $Colors] !! 0;
                    my Int $result = ($nums[ $ptr++ ] - $prev-color) +& $bit-mask;
                    @output.push: $result;
                }
            }
        }

        return buf8.new: resample( @output, $BitsPerComponent, 8);
    }

    multi method prediction($encoded where Blob | Buf,
			    Int :$Predictor! where { $_ >= 10 and $_ <= 15}, #| predictor function
			    Int :$Columns = 1,          #| number of samples per row
			    Int :$Colors = 1,           #| number of colors per sample
			    Int :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my Int $bytes-per-col = ($Colors * $BitsPerComponent  +  7) div 8;
        my Int $bytes-per-row = $bytes-per-col * $Columns;
        my Int $ptr = 0;
        my Int $row = 0;
        my @output;

        while $ptr < +$encoded {

            $row++;
            @output.push: 4; # Paeth indicator

            for 1 .. $bytes-per-row -> $i {
                my Int $left-byte = $i <= $bytes-per-col ?? 0 !! $encoded[$ptr - $bytes-per-col];
                my Int $up-byte = $row > 1 ?? $encoded[$ptr - $bytes-per-row] !! 0;
                my Int $up-left-byte = $row > 1 && $i > $bytes-per-col ?? $encoded[$ptr - $bytes-per-row -1] !! 0;

                my Int $p = $left-byte + $up-byte - $up-left-byte;

                my Int $pa = abs($p - $left-byte);
                my Int $pb = abs($p - $up-byte);
                my Int $pc = abs($p - $up-left-byte);
                my Int $nearest;

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
        return buf8.new: @output;
    }

    # prediction filters, see PDF 1.7 sepc table 3.8
    multi method prediction($encoded where Blob | Buf,
			    Int :$Predictor=1, #| predictor function
        ) {
        die "Unknown Flate/LZW predictor function: $Predictor"
            unless $Predictor == 1;
        $encoded;
    }

    # prediction filters, see PDF 1.7 sepc table 3.8
    multi method post-prediction($decoded where Blob | Buf, 
                                 Int :$Predictor! where { $_ == 2}, #| predictor function
                                 Int :$Columns = 1,          #| number of samples per row
                                 Int :$Colors = 1,           #| number of colors per sample
                                 Int :$BitsPerComponent = 8, #| number of bits per color
        ) {
        my Int $bit-mask = 2 ** $BitsPerComponent  -  1;
        my Int $ptr = 0;
        my Buf $nums = resample( $decoded, 8, $BitsPerComponent );
        my @output;

        while $ptr < +$nums {

            my @pixels = 0 xx $Colors;

            for 1  .. $Columns {

                for 0 ..^ $Colors {
                    @pixels[$_] = (@pixels[$_] + $nums[ $ptr++ ]) +& $bit-mask;
                }

                @output.push: @pixels;
            }
        }

        return buf8.new: resample( @output, $BitsPerComponent, 8);
    }

    multi method post-prediction($decoded where Blob | Buf,  #| input stream
                                 Int :$Predictor! where { $_ >= 10 and $_ <= 15}, #| predictor function
                                 Int :$Columns = 1,          #| number of samples per row
                                 Int :$Colors = 1,           #| number of colors per sample
                                 Int :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my Int $bytes-per-col = ($Colors * $BitsPerComponent  +  7) div 8;
        my Int $bytes-per-row = $bytes-per-col * $Columns;
        my Int $ptr = 0;
        my @output;

        my @up = 0 xx $bytes-per-row;

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
                        my Int $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                        @out.push: ($decoded[$ptr++] + $left-byte) % 256;
                    }
                }
                when 2 {
                    # Up - 2
                    for 1 .. $bytes-per-row {
                        my Int $up-byte = @up[ +@out ];
                        @out.push: ($decoded[$ptr++] + $up-byte) % 256;
                    }
                }
                when  3 {
                    # Average - 3
                    for 1 .. $bytes-per-row -> $i {
                        my Int $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                        my Int $up-byte = @up[ +@out ];
                        @out.push: ($decoded[$ptr++] + ( ($left-byte + $up-byte) div 2 )) % 256;
                    }
                }
                when 4 {
                    # Paeth - 4
                    for 1 .. $bytes-per-row -> $i {
                        my Int $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                        my Int $up-byte = @up[ +@out ];
                        my Int $up-left-byte = $i <= $bytes-per-col ?? 0 !! @up[ +@out - $bytes-per-col];
                        my Int $p = $left-byte + $up-byte - $up-left-byte;

                        my Int $pa = abs($p - $left-byte);
                        my Int $pb = abs($p - $up-byte);
                        my Int $pc = abs($p - $up-left-byte);
                        my Int $nearest;

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
        return buf8.new: @output;
    }

    multi method post-prediction($decoded where Blob | Buf,
                                 Int :$Predictor=1, #| predictor function 
        ) {
        die "Unknown Flate/LZW predictor function: $Predictor"
            unless $Predictor == 1;
        $decoded;
    }

}
