use v6;

class PDF::Basic::Filter {

    use PDF::Basic::Filter::ASCIIHex;
    use PDF::Basic::Filter::Flate;
    use PDF::Basic::Filter::RunLength;

    multi method decode( $input, Hash :$dict! where .<Filter>:!exists) {
        # nothing to do
        $input;
    }

    multi method decode( $input, Hash :$dict! ) {
        $.filter-class( $dict<Filter> ).decode( $input, :$dict );
    }

    multi method encode( $input, Hash :$dict! ) {
        $.filter-class( $dict<Filter> ).encode( $input, :$dict );
    }

    method filter-class( Str $filter-name is copy ) {

        BEGIN my %Filters =
            ASCIIHexDecode => PDF::Basic::Filter::ASCIIHex,
            ASCII85Decode  => Mu,
            CCITTFaxDecode => Mu,
            Crypt          => Mu,
            DCTDecode      => Mu,
            FlateDecode    => PDF::Basic::Filter::Flate,
            JBIG2Decode    => Mu,
            JPXDecode      => Mu,
            RunLengthDecode => PDF::Basic::Filter::RunLength,
            ;

        BEGIN my %FilterAbbreviations =
            AHx => 'ASCIIHexDecode',
            A85 => 'ASCII85Decode',
            LZW => 'LZWDecode LZW',
            Fl  => 'FlateDecode',
            RL  => 'RunLengthDecode',
            CCF => 'CCITTFaxDecode',
            DCT => 'DCTDecode',
            ;

        $filter-name = %FilterAbbreviations{$filter-name}
            if %FilterAbbreviations{$filter-name}:exists;

        die "unknown filter: $filter-name"
            unless %Filters{$filter-name}:exists;

        my $filter-class = %Filters{$filter-name};

        die "filter not implemented: '$filter-name'"
            unless $filter-class.can('decode');

        $filter-class;
    }

}
