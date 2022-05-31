use v6;
# code adapted from Perl's PDF::API2::Basic::PDF::Filter::LZWEncode
# getCode() adapted from xPDF's LZWStream::getCode()
class PDF::IO::Filter::LZW {

    # Maintainer's Note: LZW is described in the PDF 32000 spec
    # in section 7.4.4
    use PDF::COS;
    use PDF::IO::Util;
    use PDF::IO::Filter::Predictors;
    use PDF::IO::Blob;

    my constant InitialCodeLen = 9;
    my constant ClearTable = 256;
    my constant EodMarker = 257;
    my constant DictSize = 256;

    sub predictor-class {
        # load a faster alternative, if available
        state $ = INIT given try {require ::('PDF::Native::Filter::Predictors')} {
            $_ === Nil ?? PDF::IO::Filter::Predictors !! $_;
        }
    }

    multi method encode($) {
	die "LZW encoding is not implemented.";
    }

    multi method decode(Str $_, |c) {
	$.decode( .encode("latin-1"), |c);
    }
    multi method decode(Blob $in, :$Predictor, :$EarlyChange = 1, |c --> Blob) {

        my int32 $next-code = 258;
        my int32 $code-len = InitialCodeLen;
        my @table = map *.Array, (^DictSize);
        my uint8 @out;
        my int32 $i = 0;
        my int32 $inputBuf = 0;
        my int32 $inputBits = 0;

        loop {
            my int32 $code = getCode($in, $i, $inputBuf, $inputBits, $code-len);

            unless $EarlyChange {
                if $next-code == (1 +< $code-len) and $code-len < 12 {
                    $code-len++;
                }
            }

            if $code == ClearTable {
                $code-len = InitialCodeLen;
                $next-code = EodMarker + 1;
                next;
            }
            elsif $code == EodMarker {
                last;
            }
            else {
                @table[$next-code] = @table[$code].clone;
                @table[$next-code].push: @table[$code + 1][0]
                    if $code > EodMarker;
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

    sub getCode(Blob $in, $i is rw, $inputBuf is rw, $inputBits is rw, $nextBits) {

        while $inputBits < $nextBits {
            my $v := $in[$i++] // return EodMarker;
            $inputBuf = ($inputBuf +< 8) + $v;
            $inputBits += 8;
        }

        $inputBits -= $nextBits;
        ($inputBuf +> $inputBits) +& ((1 +< $nextBits) - 1);
    }
}
