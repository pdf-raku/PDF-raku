use v6;
# based on Perl 5's PDF::API::Core::PDF::Filter::ASCIIHexDecode

class PDF::IO::Filter::ASCIIHex {

    # Maintainer's Note: ASCIIHexDecode is described in the PDF 1.7 spec
    # in section 7.4.2.
    use PDF::IO::Blob;
    use PDF::IO::Util :resample;
    BEGIN my uint8 @HexEnc = map *.ord, flat '0' .. '9', 'a' .. 'f';


    multi method encode(Str $input, |c --> PDF::IO::Blob) {
	$.encode( $input.encode("latin-1"), |c)
    }
    multi method encode(Blob $input --> PDF::IO::Blob) {

	my @buf = resample( $input, 8, 4).map: {@HexEnc[$_]};
	@buf.push: '>'.ord;

	PDF::IO::Blob.new( @buf );
    }

    multi method decode(Blob $input, |c) {
	$.decode( $input.decode("latin-1"), |c);
    }
    multi method decode(Str $input, Bool :$eod = False --> PDF::IO::Blob) {

        my Str $str = $input.subst(/\s/, '', :g).lc;

        if $str.ends-with('>') {
            $str = $str.chop;
        }
        else {
           die "missing end-of-data marker '>' at end of hexadecimal encoding"
               if $eod
        }

        # "If the filter encounters the EOD marker after reading an odd
        # number of hexadecimal digits, it shall behave as if a 0 (zero)
        # followed the last digit."

        $str ~= '0'
            unless $str.codes %% 2;

        my @HexDec;
        BEGIN {
            for @HexEnc.pairs -> \hi {
                for @HexEnc.pairs {
                    @HexDec[hi.value][.value] = hi.key +< 4  +  .key;
                }
            }
        }

        my uint8 @bytes = $str.ords.map: -> \a, \b { @HexDec[a;b] //  die "Illegal character(s) found in ASCII hex-encoded stream: {(a~b).perl}" };

	PDF::IO::Blob.new( @bytes );
    }
}