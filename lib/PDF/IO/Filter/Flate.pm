use v6;
# based on Perl 5's PDF::API::Core::PDF::Filter::ASCIIHexDecode

use PDF::IO::Filter::Predictors;

class PDF::IO::Filter::Flate
    does PDF::IO::Filter::Predictors {

    use Compress::Zlib;
    use PDF::IO::Blob;

    # Maintainer's Note: Flate is described in the PDF 1.7 spec in section 3.3.3.
    # See also http://www.libpng.org/pub/png/book/chapter09.html - PNG predictors

    multi method encode(Str $input, |c) {
	$.encode( $input.encode('latin-1'), |c );
    }

    multi method encode(Blob $decoded, :$Predictor, |c --> PDF::IO::Blob) is default {
        PDF::IO::Blob.new: compress($Predictor ?? $.prediction( $_, :$Predictor, |c ) !! $_)
            with $decoded;
    }

    multi method decode(Str $encoded, |c) {
	$.decode( $encoded.encode('latin-1'), |c);
    }

    multi method decode(Blob $encoded, :$Predictor, |c --> PDF::IO::Blob) {
        PDF::IO::Blob.new: ($Predictor ?? $.post-prediction( $_, :$Predictor, |c ) !! $_)
            with uncompress( $encoded );
    }
}
