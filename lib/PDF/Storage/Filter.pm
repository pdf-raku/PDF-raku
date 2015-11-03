use v6;

class PDF::Storage::Filter {

    use PDF::Storage::Filter::ASCIIHex;
    use PDF::Storage::Filter::ASCII85;
    use PDF::Storage::Filter::Flate;
    use PDF::Storage::Filter::LZW;
    use PDF::Storage::Filter::RunLength;
    use PDF::Storage::Blob;

    # chosen because, should have an underlying uint 8 representation and should stringfy
    # easily via :  ~$blob or $blob.Str
    subset ByteBlob of Blob where {.encoding eq 'latin-1' }

    proto method decode($, Hash :$dict!) returns ByteBlob {*}
    proto method encode($, Hash :$dict!) returns ByteBlob {*}

    multi method decode( $input, Hash :$dict! where !.<Filter>.defined --> ByteBlob) {
        # nothing to do
        $input;
    }

    # object may have an array of filters PDF 1.7 spec Table 3.4 
    multi method decode( $data is copy, Hash :$dict! where .<Filter>.isa(List) --> ByteBlob) {

        if $dict<DecodeParms>:exists {
            die "Filter array {.<Filter>} does not have a corresponding DecodeParms array"
                if $dict<DecodeParms>:exists
                && (!$dict<DecodeParms>.isa(List) || +$dict<Filter> != +$dict<DecodeParms>);
        }

        for $dict<Filter>.keys -> $i {
            my %dict = Filter => $dict<Filter>[$i];
            %dict<DecodeParms> = %( $dict<DecodeParms>[$i] )
                if $dict<DecodeParms>:exists;

            $data = $.decode( $data, :%dict )
        }

        $data;
    }

    multi method decode( $input, Hash :$dict! --> ByteBlob ) {
        my %params = %( $dict<DecodeParms> )
            if $dict<DecodeParms>:exists; 
        $.filter-class( $dict<Filter> ).decode( $input, |%params);
    }

    # object may have an array of filters PDF 1.7 spec Table 3.4 
    multi method encode( $data is copy, Hash :$dict! where .<Filter>.isa(List) --> ByteBlob ) {

        if $dict<DecodeParms>:exists {
            die "Filter array {.<Filter>} does not have a corresponding DecodeParms array"
                if $dict<DecodeParms>:exists
                && (!$dict<DecodeParms>.isa(List) || +$dict<Filter> != +$dict<DecodeParms>);
        }

        for $dict<Filter>.keys.reverse -> $i {
            my %dict = Filter => $dict<Filter>[$i];
            %dict<DecodeParms> = %( $dict<DecodeParms>[$i] )
                if $dict<DecodeParms>:exists;

            $data = $.encode( $data, :%dict )
        }

        $data;
    }

    multi method encode( $input, Hash :$dict! --> ByteBlob ) {
        my %params = %( $dict<DecodeParms> )
            if $dict<DecodeParms>:exists;
        $.filter-class( $dict<Filter> ).encode( $input, |%params);
    }

    method filter-class( Str $filter-name is copy ) {

        BEGIN my %Filters =
            ASCIIHexDecode => PDF::Storage::Filter::ASCIIHex,
            ASCII85Decode  => PDF::Storage::Filter::ASCII85,
            CCITTFaxDecode => Mu,
            Crypt          => Mu,
            DCTDecode      => Mu,
            FlateDecode    => PDF::Storage::Filter::Flate,
            LZWDecode      => PDF::Storage::Filter::LZW,
            JBIG2Decode    => Mu,
            JPXDecode      => Mu,
            RunLengthDecode => PDF::Storage::Filter::RunLength,
            ;

        BEGIN my %FilterAbbreviations =
            AHx => 'ASCIIHexDecode',
            A85 => 'ASCII85Decode',
            LZW => 'LZWDecode',
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
