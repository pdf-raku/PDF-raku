use v6;
# based on PDF::API::Core::PDF::Filter::RunLengthDecode

class PDF::IO::Filter::RunLength {

    # Maintainer's Note: RunLengthDecode is described in the PDF 32000 spec
    # in section 7.4.5.
    use PDF::IO::Blob;

    multi method encode(Blob \input --> PDF::IO::Blob) {
        my uint8 @out;
        my \n = input.elems - 1;
        my int $i = 0;
        my int $j = 0;

        while $i <= n {
            my uint $ind = 0;
            my $ind-pos = $j++;
            my \ord = input[$i++];
            @out[$j++] = ord;

            if $i > n || ord == input[$i] {
                # run of repeated bytes
                $ind = 256;
                while $i <= n && input[$i] == ord && $ind > 129 {
                    $i++;
                    $ind--;
                }
            }
            else {
                # literal sequence
                $ind = 0;
                while ($i < n && input[$i] != input[$i+1]) || $i == n {
                    last if $ind >= 127;
                    @out[$j++] = input[$i++];
                    $ind++;
                }
            }
            @out[$ind-pos] = $ind;
        }

        @out[$j] = 128;

	PDF::IO::Blob.new: @out
    }

    multi method encode(Str \input ) {
        $.encode( input.encode("latin-1") )
    }

    multi method decode(Blob \input, Bool :$eod = True --> PDF::IO::Blob) {

        my int $idx = 0;
        my uint8 @out;
        my \n = input.elems;

        while $idx < n {
            given (my \m := input[$idx++]) <=> 128 {
                when Less {
                    # literal sequence
                    @out.push: input[$idx++] for 0 .. m;
                }
                when More {
                    # run of repeating characters
                    @out.append: input[ $idx ] xx (257 - m);
                    $idx++;
                }
                when Same {
                    #eod
                    die "unexpected end-of-data marker (0x80)"
                        unless $idx == n;
                    last;
                }
            }
        }

        die "missing end-of-data at end of run-length encoding"
            if $eod && (n == 0 || input.tail != 128);

        PDF::IO::Blob.new: @out;
    }

    multi method decode(Str \input ) {
        $.decode( input.encode("latin-1") )
    }

}
