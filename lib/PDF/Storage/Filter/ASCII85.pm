use v6;

class PDF::Storage::Filter::ASCII85 {

    use PDF::Storage::Util :resample;

    # Maintainer's Note: ASCIIH85Decode is described in the PDF 1.7 spec
    # in section 3.2.2.

    method encode(Str $input, Bool :$eod --> Str) {

        my Int $chars = $input.chars;
        my Str $padding = 0.chr  x  (-$chars % 4);
        my $buf = ($input ~ $padding).encode('latin-1');
        my @buf32 = resample( $buf, 8, 32);

        my @a85;
        for @buf32.reverse {
            if my $n = $_ {
                for 0 .. 4 {
                    @a85.unshift: ($n % 85  +  33).chr;
                    $n div= 85;
                }
            }
            else {
                @a85.unshift: 'z';
           }
        };

        if $padding.chars {
            @a85[*-1] = <! ! ! ! !>
                if @a85[*-1] eq 'z';
            @a85.pop for 1 .. $padding.chars;
        }

        @a85.push('~>') if $eod;

        [~] @a85;
    }

    method decode(Str $input, Bool :$eod --> Str) {

        my Str $str = $input.subst(/\s/, '', :g).subst(/z/, '!!!!', :g);

        if $str.chars && $str.substr(*-2) eq '~>' {
            $str = $str.substr(0, *-2);
        }
        else {
           die "missing end-of-data marker '>' at end of hexidecimal encoding"
               if $eod
        }

        die "invalid ASCII85 encoded character: {(~$0).perl}"
            if $str ~~ /(.**0..5<-[\!..\u\z]>)/;

        my $padding = 'u' x (-$str.chars % 5);
        my $buf = ($str ~ $padding).encode('latin-1');

        my @buf32;
        for $buf.list.keys {
            @buf32.push: 0 if $_ %% 5;
            @buf32[*-1] *= 85;
            @buf32[*-1] += $buf[$_] - 33;
        }

        my @buf = resample(@buf32, 32, 8);
        @buf.pop for 1 .. $padding.chars;

        @buf.chrs;
    }

}
