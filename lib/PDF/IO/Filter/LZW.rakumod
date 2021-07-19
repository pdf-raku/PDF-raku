use v6;
# code adapted from Perl's PDF::API2::Basic::PDF::Filter::LZWEncode
# getCode() adapted from xPDF's LZWStream::getCode()
class PDF::IO::Filter::LZW {


    # Maintainer's Note: LZW is described in the PDF 32000 spec
    # in section 7.4.4
    use PDF::IO::Util;
    use PDF::IO::Filter::Predictors;
    use PDF::IO::Blob;

    sub predictor-class {
        state $predictor-class = PDF::IO::Util::have-pdf-native()
            ?? (require ::('PDF::Native::Filter::Predictors'))
            !! PDF::IO::Filter::Predictors;
        $predictor-class
    }

    multi method encode($) {
	die "LZW encoding is not implemented.";
    }

    multi method decode(Str $_, |c) {
	$.decode( .encode("latin-1"), |c);
    }
    multi method decode(Blob $in, :$Predictor, :$EarlyChange = 1, |c --> Blob) is default {

        my constant initial-code-len = 9;
        my constant clear-table = 256;
        my constant eod-marker = 257;
        my constant dict-size = 256;
        my uint16 $next-code = 258;
        my uint16 $code-len = initial-code-len;
        my @table = map {[$_,]}, (0 ..^ dict-size);
        my uint8 @data = $in.list;
        my uint8 @out;

        my int32 $inputBuf = 0;
        my uint16 $inputBits = 0;

        while @data {
            my $code = getCode(@data, $inputBuf, $inputBits, $code-len)
                // last;

            unless $EarlyChange {
                if $next-code == (1 +< $code-len) and $code-len < 12 {
                    $code-len++;
                }
            }

            if $code == clear-table {
                $code-len = initial-code-len;
                $next-code = eod-marker + 1;
                next;
            }
            elsif $code == eod-marker {
                last;
            }
            else {
                @table[$next-code] = @table[$code].clone;
                @table[$next-code].push: @table[$code + 1][0]
                    if $code > eod-marker;
            }

            @out.append: @table[$next-code++];

            if $EarlyChange {
                if $next-code == (1 +< $code-len) and $code-len < 12 {
                    $code-len++;
                }
            }
        }

        my $out = buf8.new: @out;

        if $Predictor {
            $out = $.predictor-class.decode( $out, :$Predictor, |c );
        }

       PDF::IO::Blob.new: $out;
    }

    sub getCode(@data, $inputBuf is rw, $inputBits is rw, $nextBits) {

        while $inputBits < $nextBits {
            return Mu unless @data;
            $inputBuf = ($inputBuf +< 8) + @data.shift;
            $inputBits += 8;
        }

        my uint32 $code = ($inputBuf +> ($inputBits - $nextBits)) +& ((1 +< $nextBits) - 1);
        $inputBits -= $nextBits;
        $code;
    }
}
