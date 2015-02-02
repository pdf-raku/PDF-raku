use v6;

class PDF::Tools::Filter::Mixin::Predictors;

use PDF::Tools::Util :resample;
# post prediction functions as described in the PDF 1.7 spec, table 3.8
multi method post-prediction($decoded, 
                             Int :$Predictor! where { $_ <= 1}, #| predictor function
    ) {
    $decoded; # noop
}

multi method prediction($decoded, 
                        Int :$Predictor! where { $_ == 2}, #| predictor function
                        Int :$Columns = 1,          #| number of samples per row
                        Int :$Colors = 1,           #| number of colors per sample
                        Int :$BitsPerComponent = 8, #| number of bits per color
    ) {
    my $bit-mask = 2 ** $BitsPerComponent  -  1;
    my @output;
    my $ptr = 0;
    my $nums = resample( $decoded, 8, $BitsPerComponent );

    while $ptr < +$nums {
        for 1 .. $Columns -> $i {
            for 1 .. $Colors {
                my $prev-color = $i > 1 ?? $nums[ $ptr - $Colors] !! 0;
                my $result = ($nums[ $ptr++ ] - $prev-color) +& $bit-mask;
                @output.push: $result;
            }
        }
    }

    return buf8.new: resample( @output, $BitsPerComponent, 8);
}

multi method prediction($encoded,
                         Int :$Predictor! where { $_ >= 10 and $_ <= 15}, #| predictor function
                         Int :$Columns = 1,          #| number of samples per row
                         Int :$Colors = 1,           #| number of colors per sample
                         Int :$BitsPerComponent = 8, #| number of bits per color
    ) {

    my $bytes-per-col = ($Colors * $BitsPerComponent  +  7) div 8;
    my $bytes-per-row = $bytes-per-col * $Columns;
    my @output;

    my $ptr = 0;
    my $row = 0;

    while $ptr < +$encoded {

        $row++;
        @output.push: 4; # Paeth indicator

        for 1 .. $bytes-per-row -> $i {
            my $left-byte = $i <= $bytes-per-col ?? 0 !! $encoded[$ptr - $bytes-per-col];
            my $up-byte = $row > 1 ?? $encoded[$ptr - $bytes-per-row] !! 0;
            my $up-left-byte = $row > 1 && $i > $bytes-per-col ?? $encoded[$ptr - $bytes-per-row -1] !! 0;

            my $p = $left-byte + $up-byte - $up-left-byte;
                    
            my $pa = abs($p - $left-byte);
            my $pb = abs($p - $up-byte);
            my $pc = abs($p - $up-left-byte);
            my $nearest;

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
multi method prediction( $encoded,
                         Int :$Predictor=1, #| predictor function
    ) {
    die "Uknown Flate/LZW predictor function: $Predictor"
        unless $Predictor == 1;
    $encoded;
}

# prediction filters, see PDF 1.7 sepc table 3.8
multi method post-prediction($decoded, 
                             Int :$Predictor! where { $_ == 2}, #| predictor function
                             Int :$Columns = 1,          #| number of samples per row
                             Int :$Colors = 1,           #| number of colors per sample
                             Int :$BitsPerComponent = 8, #| number of bits per color
    ) {
    my $bit-mask = 2 ** $BitsPerComponent  -  1;
    my @output;
    my $ptr = 0;
    my $nums = resample( $decoded, 8, $BitsPerComponent );

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

multi method post-prediction($decoded,               #| input stream
                             Int :$Predictor! where { $_ >= 10 and $_ <= 15}, #| predictor function
                             Int :$Columns = 1,          #| number of samples per row
                             Int :$Colors = 1,           #| number of colors per sample
                             Int :$BitsPerComponent = 8, #| number of bits per color
    ) {

    my $bytes-per-col = ($Colors * $BitsPerComponent  +  7) div 8;
    my $bytes-per-row = $bytes-per-col * $Columns;
    my @output;

    my $ptr = 0;
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
                    my $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                    @out.push: ($decoded[$ptr++] + $left-byte) % 256;
                }
            }
            when 2 {
                # Up - 2
                for 1 .. $bytes-per-row {
                    my $up-byte = @up[ +@out ];
                    @out.push: ($decoded[$ptr++] + $up-byte) % 256;
                }
            }
            when  3 {
                # Average - 3
                for 1 .. $bytes-per-row -> $i {
                    my $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                    my $up-byte = @up[ +@out ];
                    @out.push: ($decoded[$ptr++] + ( ($left-byte + $up-byte) div 2 )) % 256;
                }
            }
            when 4 {
                # Paeth - 4
                for 1 .. $bytes-per-row -> $i {
                    my $left-byte = $i <= $bytes-per-col ?? 0 !! @out[* - $bytes-per-col];
                    my $up-byte = @up[ +@out ];
                    my $up-left-byte = $i <= $bytes-per-col ?? 0 !! @up[ +@out - $bytes-per-col];
                    my $p = $left-byte + $up-byte - $up-left-byte;
                    
                    my $pa = abs($p - $left-byte);
                    my $pb = abs($p - $up-byte);
                    my $pc = abs($p - $up-left-byte);
                    my $nearest;

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
        @output.push: @out;
    }
    return buf8.new: @output;
}

multi method post-prediction($decoded,
                             Int :$Predictor=1, #| predictor function 
    ) {
    die "Uknown Flate/LZW predictor function: $Predictor"
        unless $Predictor == 1;
    $decoded;
}

