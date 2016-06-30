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

    method decode( $input, Hash :$dict ) is default {
        with $dict<Filter> {
            when $.have-backend { $.filter-backend.encode( $input, :$dict) }
            when Str  { self!decode-item( $input, |$dict) }
            when List { self!decode-list( $input, |$dict) }
            default { die "bad filter: $_" }
        }
        else {
            # nothing to do
            $input
        }
    }

    method !decode-item( $input, Str :$Filter, :%DecodeParms) {
        $.filter-class( $Filter ).decode( $input, |%DecodeParms);
    }

    # object may have an array of filters [PDF 1.7 spec Table 5]
    method !decode-list( $data is copy, List :$Filter, :$DecodeParms) {
        with $DecodeParms {
            die "Filter array {$Filter} does not have a corresponding DecodeParms array"
                if !.isa(List) || +$Filter != +$DecodeParms;
        }

        for $Filter.keys -> $i {
            my %dict = Filter => $Filter[$i];
            %dict<DecodeParms> = .[$i]
                with $DecodeParms;

            $data = self!decode-item( $data, |%dict )
        }

        $data;
    }

    method encode( $input, Hash :$dict ) is default {
        with $dict<Filter> {
            when $.have-backend { $.filter-backend.encode( $input, :$dict) }
            when Str  { self!encode-item( $input, |$dict) }
            when List { self!encode-list( $input, |$dict) }
            default { die "bad filter: $_" }
        }
        else {
            # nothing to do
            $input
        }
    }

    method !encode-item( $input, Str :$Filter!, :%DecodeParms) {
        $.filter-class( $Filter ).encode( $input, |%DecodeParms);
    }

    # object may have an array of filters PDF 1.7 spec Table 3.4 
    method !encode-list( $data is copy, List :$Filter!, :$DecodeParams) {

        with $DecodeParams {
            die "Filter array {$Filter} does not have a corresponding DecodeParms array"
                if !.isa(List) || +$Filter != +$_;
        }

        for $Filter.keys.reverse -> $i {
            my %dict = Filter => $Filter[$i];
            %dict<DecodeParms> = .[$i]
                with $DecodeParams;

            $data = self!encode-item( $data, |%dict )
        }

        $data;
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
