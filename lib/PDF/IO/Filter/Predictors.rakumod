use v6;

class PDF::IO::Filter::Predictors {

    subset BPC of UInt where 1 | 2 | 4 | 8 | 16 | 32;

    constant None = 1;
    constant TIFF = 2;
    constant PNG = 10;
    constant PNG-Range = 10 .. 15;

    subset Predictor of Int where None | TIFF | PNG-Range;

    use PDF::IO::Util :pack;
    # post prediction functions as described in the PDF 32000 spec, Table 9

    multi method encode($buf where Blob | Buf,
                        Predictor :$Predictor! where TIFF, #| predictor function
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
			Predictor :$Predictor! where PNG-Range, #| predictor function
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
        my uint $row-size = ($colors * $bpc * $Columns + 7) div 8;
        my uint $idx = 0;
        my uint8 @out;
        my uint $tag = min($Predictor - 10, 4);
        my int $n = 0;
        my $rows = +$buf div $row-size;
        # preallocate, allowing room for per-row data + tag
        @out[$rows * ($row-size + 1) - 1] = 0
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
                        @out[$n++] = $buf[$idx++] - left-val;
                    }
                }
                when 2 { # Up
                    for 1 .. $row-size {
                        my \up-val = $row ?? $buf[$idx - $row-size] !! 0;
                        @out[$n++] = $buf[$idx++] - up-val;
                    }
                }
                when 3 { # Average
                    for 1 .. $row-size -> int $i {
                        my \left-val = $i <= $colors ?? 0 !! $buf[$idx - $colors];
                        my \up-val = $row ?? $buf[$idx - $row-size] !! 0;
                        @out[$n++] = $buf[$idx++] - (left-val + up-val) div 2;
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
                        @out[$n++] = $buf[$idx++] - nearest;
                   }
                }
            }
        }

        blob8.new(@out);
    }

    multi method encode($buf where Blob | Buf,
			Predictor :$Predictor where None = None #| predictor function
        ) {
        $buf;
    }

    multi method decode($buf where Blob | Buf,
                        Predictor :$Predictor! where TIFF, #| predictor function
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

                for ^$Colors {
                    @pixels[$_] = (@pixels[$_] + nums[ $idx++ ]) +& $bit-mask;
                }

                @output.append: @pixels;
            }
        }

        pack( @output, $BitsPerComponent);
    }

    multi method decode($buf is copy where Blob | Buf,  #| input stream
                        Predictor :$Predictor! where PNG-Range, #| predictor function
                        UInt :$Columns = 1,          #| number of samples per row
                        UInt :$Colors = 1,           #| number of colors per sample
                        BPC :$BitsPerComponent = 8,  #| number of bits per color
        ) {

        my uint $bpc = $BitsPerComponent;
        my uint $colors = $Colors;
        if $bpc > 8 {
            $colors *= $bpc div 8;
            $bpc = 8;
        }
        my uint $idx = 0;
        my uint8 @out;
        my int $n = 0;

        my uint $row-size = ($colors * $bpc * $Columns + 7) div 8;

        # each input row also has a tag
        my $rows = +$buf div ($row-size + 1);
        # preallocate
        @out[$rows * $row-size - 1] = 0
            if $rows;

        loop (my uint $row = 0; $row < $rows; $row++) {
            # PNG prediction can vary from row to row
            my UInt $tag = $buf[$idx++];

            given $tag {
                when 0 { # None
                    @out[$n++] = $buf[$idx++]
                        for 1 .. $row-size;
                }
                when 1 { # Left
                    @out[$n++] = $buf[$idx++] for ^$colors;
                    for $colors ^.. $row-size {
                        my \left-val = @out[$n - $colors];
                        @out[$n++] = $buf[$idx++] + left-val;
                    }
                }
                when 2 { # Up
                    for ^$row-size {
                        my \up-val = $row ?? @out[$n - $row-size] !! 0;
                        @out[$n++] = $buf[$idx++] + up-val;
                    }
                }
                when  3 { # Average
                    for ^$row-size -> int $i {
                        my \left-val = $i < $colors ?? 0 !! @out[$n - $colors];
                        my \up-val = $row ?? @out[$n - $row-size] !! 0;
                        @out[$n++] = $buf[$idx++] + (left-val + up-val) div 2;
                    }
                }
                when 4 { # Paeth
                    for ^$row-size -> \i {
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

                        @out[$n++] = $buf[$idx++] + nearest;
                    }
                }
                default {
                    die "bad PNG predictor tag: $_";
                }
            }
        }

        blob8.new(@out);
    }

    multi method decode($buf, Predictor :$Predictor where {None} = None ) {
        $buf;
    }

}
