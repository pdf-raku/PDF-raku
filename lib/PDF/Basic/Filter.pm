use v6;

class PDF::Basic::Filter {

    use PDF::Basic::Filter::ASCIIHex;
    use PDF::Basic::Filter::Flate;
    use PDF::Basic::Filter::RunLength;

    multi method decode( $input, Hash :$dict! where !.<Filter>.defined) {
        # nothing to do
        $input;
    }

    # object may have an array of filters PDF 1.7 spec Table 3.4 
    multi method decode( $data is copy, Hash :$dict! where .<Filter>.isa(List) ) {

        if $dict<DecodeParams>:exists {
            die "Filter array {.<Filter>} does not have a corresponding DecodeParams array"
                if $dict<DecodeParams>:exists
                && (!$dict<DecodeParams>.isa(List) || +$dict<Filter> != +$dict<DecodeParams>);
        }

        for $dict<Filter>.keys -> $i {
            my %dict = Filter => $dict<Filter>[$i];
            %dict<DecodeParams> = %( $dict<DecodeParams>[$i] )
                if $dict<DecodeParams>:exists;

            $data = $.decode( $data, :%dict )
        }

        $data;
    }

    multi method decode( $input, Hash :$dict! ) {
        my %params = %( $dict<DecodeParams> )
            if $dict<FilterParams>; 
        $.filter-class( $dict<Filter> ).decode( $input, |%params);
    }

    # object may have an array of filters PDF 1.7 spec Table 3.4 
    multi method encode( $data is copy, Hash :$dict! where .<Filter>.isa(List) ) {

        if $dict<DecodeParams>:exists {
            die "Filter array {.<Filter>} does not have a corresponding DecodeParams array"
                if $dict<DecodeParams>:exists
                && (!$dict<DecodeParams>.isa(List) || +$dict<Filter> != +$dict<DecodeParams>);
        }

        for $dict<Filter>.keys.reverse -> $i {
            my %dict = Filter => $dict<Filter>[$i];
            %dict<DecodeParams> = %( $dict<DecodeParams>[$i] )
                if $dict<DecodeParams>:exists;

            $data = $.encode( $data, :%dict )
        }

        $data;
    }

    multi method encode( $input, Hash :$dict! ) {
        my %params = %( $dict<DecodeParams> )
            if $dict<FilterParams>; 
        $.filter-class( $dict<Filter> ).encode( $input, |%params);
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
