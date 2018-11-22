use v6;

class PDF::IO::Filter::Flate {

    use PDF::IO::Filter::Predictors;
    use Compress::Zlib;
    use PDF::IO::Blob;
    use PDF::IO::Util;

    # Maintainer's Note: Flate is described in the PDF 32000 spec in section 7.4.4.
    # See also http://www.libpng.org/pub/png/book/chapter09.html - PNG predictors
    sub predictor-class {
        state $predictor-class = PDF::IO::Util::libpdf-available()
            ?? (require ::('PDF::Native::Filter::Predictors'))
            !! PDF::IO::Filter::Predictors;
        $predictor-class
    }

    multi method encode(Blob $decoded, :$Predictor, |c --> PDF::IO::Blob) is default {
        PDF::IO::Blob.new: compress($Predictor ?? predictor-class.encode( $_, :$Predictor, |c ) !! $_)
            with $decoded;
    }
    multi method encode(Str $input, |c) {
	$.encode( $input.encode('latin-1'), |c );
    }

    multi method decode(Blob $encoded, :$Predictor, |c --> PDF::IO::Blob) {
        PDF::IO::Blob.new: ($Predictor ?? predictor-class.decode( $_, :$Predictor, |c ) !! $_)
            with uncompress( $encoded );
    }
    multi method decode(Str $encoded, |c) {
	$.decode( $encoded.encode('latin-1'), |c);
    }

}
