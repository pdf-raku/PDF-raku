use v6;

use PDF::Object::Dict;
use PDF::Object::Type;
use Font::Encoding::PDF;

# /Type /Font - Describes a font

class PDF::Object::Type::Font
    is PDF::Object::Dict
    does PDF::Object::Type {

    BEGIN our %encoders = ();

    method Subtype is rw { self<Subtype> }
    method Name is rw { self<Name> }
    method BaseFont is rw { self<BaseFont> }
    method Encoding is rw { self<Encoding> }

    method encode(Str $string) {
        my $encoding = $.Encoding
            or die 'Encoding has not been set for thsi font';

        # classic single byte encoding schemes
        # [PDF Ref 1.7 Appendix D: Character Sets and Encodings]
        BEGIN constant SingleByteEncoding = {
            StandardEncoding => 'std',
            MacRomanEncoding => 'mac',
            WinAnsiEncoding  => 'win',
            PDFDocEncoding   => 'pdf',
        };

        if SingleByteEncoding{$encoding}:exists {
            my $scheme = SingleByteEncoding{$encoding};
            my $encoder = (%encoders{$scheme} //= Font::Encoding::PDF.new( $scheme ));
            return $encoder.encode( $string ).decode('latin-1');
        }

        die "unknown/unsupported encoding scheme: $encoding";

    }

}

