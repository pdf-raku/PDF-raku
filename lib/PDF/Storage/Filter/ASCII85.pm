use v6;

class PDF::Storage::Filter::ASCII85 {

    use PDF::Storage::Util :resample;
    use PDF::Storage::Blob;

    # Maintainer's Note: ASCIIH85Decode is described in the PDF 1.7 spec
    # in section 3.2.2.

    multi method encode(Str $input, |c) {
	$.encode( $input.encode("latin-1"), |c);
    }

    multi method encode(Blob $buf is copy, Bool :$eod --> Blob) {

	my UInt $padding = -$buf % 4;
	my uint8 @buf = $buf.list;
	@buf.push: 0 for 1..$padding;
        my uint32 @buf32 = resample( @buf, 8, 32);

	constant NullChar = 'z'.ord;
	constant PadChar = '!'.ord;
	constant EOD = '~'.ord, '>'.ord; 

        my uint8 @a85;
        for @buf32.reverse {
            if my $n = $_ {
                for 0 .. 4 {
                    @a85.unshift: ($n % 85  +  33);
                    $n div= 85;
                }
            }
            else {
                @a85.unshift: NullChar;
           }
        };

        if $padding {
            @a85[*-1] = PadChar xx 5
                if @a85[*-1] == NullChar;
            @a85.pop for 1 .. $padding;
        }

        @a85.append: EOD if $eod;

        PDF::Storage::Blob.new( @a85 );
    }

    multi method decode(Blob $buf, |c) {
	$.decode($buf.Str, |c);
    }
    multi method decode(Str $input, Bool :$eod --> PDF::Storage::Blob) {

        my Str $str = $input.subst(/\s/, '', :g).subst(/z/, '!!!!', :g);

        if $str.chars && $str.substr(*-2) eq '~>' {
            $str = $str.substr(0, *-2);
        }
        else {
           die "missing end-of-data marker '>' at end of hexidecimal encoding"
               if $eod
        }

        die "invalid ASCII85 encoded character: {(~$0).perl}"
            if $str ~~ /(<-[\!..\u\z]>)/;

        my $padding = 'u' x (-$str.chars % 5);
        my $buf = ($str ~ $padding).encode('latin-1');

        my uint32 @buf32;
        for $buf.list.keys {
            @buf32.push: 0 if $_ %% 5;
            @buf32[*-1] *= 85;
            @buf32[*-1] += $buf[$_] - 33;
        }

        my uint8 @buf = resample(@buf32, 32, 8);
        @buf.pop for 1 .. $padding.chars;

        PDF::Storage::Blob.new: @buf;
    }

}
