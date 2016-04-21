use v6;

class PDF::Storage::Filter {

    use PDF::Storage::Filter::ASCIIHex;
    use PDF::Storage::Filter::ASCII85;
    use PDF::Storage::Filter::Flate;
    use PDF::Storage::Filter::RunLength;
    use PDF::Storage::Blob;

    #| set P6_PDF_FILTER_CLASS to enable experimental/alternate backends
    #| aka LibGnuPDF::Filter
    method filter-backend is rw {
	state $filter-backend;
    }
    method have-backend {
	state Bool $have-backend //= ? do {
	    with %*ENV<P6_PDF_FILTER_CLASS> -> $filter-name {
		try {
		    require ::($filter-name);
		    $.filter-backend = ::($filter-name);
		    # ping the library, just to make sure it's operational
		    $.filter-backend.ping;
		}
	    }
	}
    }

    proto method decode($, Hash :$dict!) {*}
    proto method encode($, Hash :$dict!) returns PDF::Storage::Blob {*}

    multi method decode( $input, Hash :$dict! where !.<Filter>.defined) {
        # nothing to do
        $input;
    }

    multi method decode( $data, Hash :$dict! where $.have-backend) {
       PDF::Storage::Blob.new: $.filter-backend.decode( $data, :$dict);
    }

    # object may have an array of filters [PDF 1.7 spec Table 5]
    multi method decode( $data is copy, Hash :$dict! where .<Filter>.isa(List)) {
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

    multi method decode( $input, Hash :$dict! ) {
        my %params = %( $dict<DecodeParms> )
            if $dict<DecodeParms>:exists; 
        $.filter-class( $dict<Filter> ).decode( $input, |%params);
    }

    multi method encode( $input, Hash :$dict! where !.<Filter>.defined) {
        # nothing to do
        $input;
    }

    multi method encode( $data, Hash :$dict! where $.have-backend) {
       PDF::Storage::Blob.new: $.filter-backend.encode( $data, :$dict);
    }

    # object may have an array of filters PDF 1.7 spec Table 3.4 
    multi method encode( $data is copy, Hash :$dict! where .<Filter>.isa(List) ) {

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

    multi method encode( $input, Hash :$dict! --> PDF::Storage::Blob ) {
        my %params = %( $dict<DecodeParms> )
            if $dict<DecodeParms>:exists;
        $.filter-class( $dict<Filter> ).encode( $input, |%params);
    }

    method filter-class( Str $filter-name is copy ) {

        constant %Filters = %(
            ASCIIHexDecode => PDF::Storage::Filter::ASCIIHex,
            ASCII85Decode  => PDF::Storage::Filter::ASCII85,
            CCITTFaxDecode => Mu,
            Crypt          => Mu,
            DCTDecode      => Mu,
            FlateDecode    => PDF::Storage::Filter::Flate,
            LZWDecode      => Mu,
            JBIG2Decode    => Mu,
            JPXDecode      => Mu,
            RunLengthDecode => PDF::Storage::Filter::RunLength,
            );

	# image object specific abbreviations :-
        # See [PDF 1.7 Table 94 – Additional Abbreviations in an Inline Image Object]
        constant %FilterAbbreviations = %(
            AHx => 'ASCIIHexDecode',
            A85 => 'ASCII85Decode',
            LZW => 'LZWDecode',
            Fl  => 'FlateDecode',
            RL  => 'RunLengthDecode',
            CCF => 'CCITTFaxDecode',
            DCT => 'DCTDecode',
            );

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
