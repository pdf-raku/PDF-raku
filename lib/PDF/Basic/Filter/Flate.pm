use v6;
# based on Perl 5's PDF::API::Basic::PDF::Filter::ASCIIHexDecode

use PDF::Basic::Filter;

class PDF::Basic::Filter::Flate
    is PDF::Basic::Filter;

use Compress::Zlib;

# Maintainer's Note: Flate is described in the PDF 1.7 spec
# in section 3.3.3.

method encode($input) {

    die 'illegal character(s) > \xFF'
        if $input.comb.grep({$_ gt "\xFF"});

    compress( $input.encode('latin-1' ) ).decode( 'latin-1' );

}

method decode($input) {

    uncompress( $input.encode('latin-1' ) ).decode( 'latin-1' );

}
