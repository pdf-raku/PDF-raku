use v6;
# based on Perl 5's PDF::API::Core::PDF::Filter::ASCIIHexDecode

class PDF::Storage::Filter::ASCIIHex {

    # Maintainer's Note: ASCIIHexDecode is described in the PDF 1.7 spec
    # in section 7.4.2.
    use PDF::Storage::Blob;

    multi method encode(Blob $input, |c) {
	$.encode( $input.decode("latin-1"), |c);
    }
    multi method encode(Str $input, Bool :$eod --> PDF::Storage::Blob) {

	BEGIN my uint8 @Hex = map *.ord, flat '0' .. '9', 'a' .. 'f';

	my uint8 @buf = flat $input.ords.map: -> $ord {
            die 'illegal wide byte: U+' ~ $ord.base(16)
                if $ord > 0xFF;
	    @Hex[$ord div 16], @Hex[$ord % 16];
	}

	@buf.push: '>'.ord if $eod;

	PDF::Storage::Blob.new( @buf );
    }

    multi method decode(Blob $input, |c) {
	$.decode( $input.decode("latin-1"), |c);
    }
    multi method decode(Str $input, Bool :$eod --> PDF::Storage::Blob) {

        my Str $str = $input.subst(/\s/, '', :g);

        if $str && $str.substr(*-1,1) eq '>' {
            $str = $str.chop;

            # "If the filter encounters the EOD marker after reading an odd
            # number of hexadecimal digits, it shall behave as if a 0 (zero)
            # followed the last digit."

            $str ~= '0'
                unless $str.chars %% 2;
        }
        else {
           die "missing end-of-data marker '>' at end of hexidecimal encoding"
               if $eod
        }

        die "Illegal character(s) found in ASCII hex-encoded stream"
            if $str ~~ m:i/< -[0..9 A..F]>/;

        my uint8 @ords = $str.comb( /..?/ ).map: { :16($_) };

	PDF::Storage::Blob.new( @ords );
    }
}
