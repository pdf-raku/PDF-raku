use v6;
# based on PDF::API::Core::PDF::Filter::RunLengthDecode

class PDF::Storage::Filter::RunLength {

    # Maintainer's Note: RunLengthDecode is described in the PDF 1.7 spec
    # in section 7.4.5.
    use PDF::Storage::Blob;

    multi method encode(Blob \input --> PDF::Storage::Blob) {
        my @out;
        my \n = input.elems - 1;
        my int $i = 0;
        my int $j = 0;

        while $i <= n {
            @out[$j++] := my int $ind;
            my \ord = input[$i++];
            @out[$j++] = ord;

            if $i > n || ord == input[$i] {
                # run of repeated characters
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
        }

        @out[$j] = 128;

	PDF::Storage::Blob.new: @out
    }

    multi method encode(Str \input ) {
        $.encode( input.encode("latin-1") )
    }

    multi method decode(Blob \input, Bool :$eod = True --> PDF::Storage::Blob) {

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
            if $eod && (n == 0 || input[*-1] != 128);

        PDF::Storage::Blob.new: @out;
    }

    multi method decode(Str \input ) {
        $.decode( input.encode("latin-1") )
    }

}
