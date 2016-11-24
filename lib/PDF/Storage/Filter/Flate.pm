use v6;
# based on Perl 5's PDF::API::Core::PDF::Filter::ASCIIHexDecode

use PDF::Storage::Filter::Predictors;

class PDF::Storage::Filter::Flate
    does PDF::Storage::Filter::Predictors {

    use Compress::Zlib;
    use PDF::Storage::Blob;

    # Maintainer's Note: Flate is described in the PDF 1.7 spec in section 3.3.3.
    # See also http://www.libpng.org/pub/png/book/chapter09.html - PNG predictors

    multi method encode(Str $input, |c) {
	$.encode( $input.encode('latin-1'), |c );
    }

    multi method encode(Blob $buf, :$Predictor, |c --> PDF::Storage::Blob) is default {
        PDF::Storage::Blob.new: compress($Predictor ?? $.prediction( $_, :$Predictor, |c ) !! $_)
            with $buf;
    }

    multi method decode(Str $input, |c) {
	$.decode( $input.encode('latin-1'), |c);
    }

    multi method decode(Blob $input, :$Predictor, |c --> PDF::Storage::Blob) {
        PDF::Storage::Blob.new: ($Predictor ?? $.post-prediction( $_, :$Predictor, |c ) !! $_)
            with uncompress( $input );
    }
}
