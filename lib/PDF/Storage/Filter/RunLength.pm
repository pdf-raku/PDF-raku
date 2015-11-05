use v6;
# based on PDF::API::Core::PDF::Filter::RunLengthDecode

class PDF::Storage::Filter::RunLength {

    # Maintainer's Note: RunLengthDecode is described in the PDF 1.7 spec
    # in section 7.4.5.
    use PDF::Storage::Blob;

    multi method encode(Blob $input, |c) {
	$.encode( $input.decode("latin-1"), |c);
    }

    multi method encode(Str $input, Bool :$eod --> PDF::Storage::Blob) {
        my @chunks;

        for $input.comb(/(.)$0**0..127/) -> $/ {

            my UInt $ord = $0.ord;
            my UInt $len = $/.codes;

            die 'illegal wide byte: U+' ~ $ord.base(16)
                if $ord > 0xFF;

            if $len > 1 {
                # run of repeating characters
                @chunks.push: $[257 - $len, $ord];
            }
            else {
                # literal sequence
                @chunks.push: $[-1]
                    unless @chunks && @chunks[*-1][0] < 127;

                for @chunks[*-1] {
                    .[0]++;
                    .push: $ord;
                }
            }
        }

        @chunks.push: $[128] if $eod;

        PDF::Storage::Blob.new: flat @chunks.map: { @$_ };
    }

    multi method decode(Blob $input, |c) {
	$.decode( $input.decode("latin-1"), |c);
    }
    multi method decode(Str $input, Bool :$eod --> PDF::Storage::Blob) {

        my UInt $idx = 0;
        my uint8 @in = $input.ords;
        my uint8 @out;

        while $idx < +@in {
            given @in[ $idx++ ] {
                when * < 128 {
                    # literal sequence
                    @out.push: @in[ $idx++ ] for 0 .. $_;
                }
                when * > 128 {
                    # run of repeating characters
                    @out.append: @in[ $idx ] xx (257 - $_);
                    $idx++;
                }
                when 128 {
                    #eod
                    die "unexpected end-of-data marker (0x80)"
                        unless $idx == +@in;
                    last;
                }
            }

            die "missing end-of-data at end of run-length encoding"
                if $eod && (+@in == 0 || @in[*-1] != 128);

        }

        PDF::Storage::Blob.new: @out;
    }
}
