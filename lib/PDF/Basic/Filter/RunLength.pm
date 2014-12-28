use v6;
# based on PDF::API::Basic::PDF::Filter::RunLengthDecode

class PDF::Basic::Filter::RunLength;

# Maintainer's Note: RunLengthDecode is described in the PDF 1.7 spec
# in section 7.4.5.

method encode(Str $input, Bool :$eod --> Str) {
    my @chunks;

    for $input.comb(/(.)$0**0..127/) -> $/ {

        my $ord = $0.ord;
        my $len = $/.chars;

        die 'illegal wide byte: U+' ~ $ord.base(16)
            if $ord > 0xFF;

        if $len > 1 {
            # run of repeating characters
            @chunks.push: [257 - $len, $ord];
        }
        else {
            # literal sequence
            @chunks.push: [-1]
                unless @chunks && @chunks[*-1][0] < 127;

            given @chunks[*-1] {
                .[0]++;
                .push: $ord;
            }
        }
    }

    @chunks.push: [128] if $eod;

    my $buf = buf8.new: [ @chunks.map: { @$_ } ];
    return $buf.decode('latin1');
}

method decode(Str $input, Bool :$eod --> Str) {

    my $idx = 0;
    my @in = $input.comb;
    my @out;

    while $idx < +@in {
        given @in[ $idx++ ].ord {
            when * < 128 {
                # literal sequence
                @out.push: @in[ $idx++ ] for 0 .. $_;
            }
            when * > 128 {
                # run of repeating characters
                @out.push: @in[ $idx ] x (257 - $_);
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
            if $eod && (+@in == 0 || @in[*-1].ord != 128);

    }

    return @out.join: '';
}
