use v6;
# based on PDF::API::Basic::PDF::Filter::RunLengthDecode

use PDF::Basic::Filter;

class PDF::Basic::Filter::RunLength
    is PDF::Basic::Filter;

# Maintainer's Note: RunLengthDecode is described in the PDF 1.7 spec
# in section 7.4.5.

method encode($input, Bool :$eod) {
    my @chunks;

    for $input.comb(/(.)$0**0..127/) -> $/ {
        my $len = $/.chars;
        die "illegal non-latin character in encoding"
            if $0.ord > 255;

        if $len > 1 {
            # run of repeating characters
            @chunks.push: [257 - $len, $0.ord];
        }
        else {
            # literal sequence
            @chunks.push: [-1]
                unless @chunks && @chunks[*-1][0] < 127;

            for @chunks[*-1] {
                .[0]++;
                .push: $0.ord;
            }
        }
    }

    @chunks.push: [128] if $eod;

    my $buf = Buf.new: [ @chunks.map: { @$_ } ];
    return $buf.decode('latin1');
}

method decode($input is copy, Bool :$eod) {
    my $output;
    my $length;

    my @in = $input.comb;
    my @chunks;

    my $idx = 0;

    while $idx < +@in {
        given @in[$idx].ord {
            when * < 128 {
                # run of repeating characters
                @chunks.push: @in[($idx + 1)..($idx + $_ + 1)];
                $idx += $_ + 2;
            }
            when * > 128 {
                # literal sequence
                @chunks.push: @in[$idx + 1] x (257 - $_);
                $idx += 2;
            }
            when 128 {
                #eod
                die "unexpected end-of-data marker (0x80)"
                    unless $idx = +@in - 1;
                last;
            }
        }

    }

    return @chunks.join: '';
}
