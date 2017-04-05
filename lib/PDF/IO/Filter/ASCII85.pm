use v6;

class PDF::IO::Filter::ASCII85 {

    use PDF::IO::Util :pack;
    use PDF::IO::Blob;

    # Maintainer's Note: ASCII85Decode is described in the PDF 1.7 spec
    # in section 3.2.2.

    multi method encode(Str $input) {
	$.encode( $input.encode("latin-1") );
    }

    multi method encode(Blob $buf --> Blob) {
	my UInt \padding = -$buf % 4;
	my uint8 @buf = $buf.list;
	@buf.append: 0 xx padding;
        my $buf32 := unpack( @buf, 32);

	constant NullChar = 'z'.ord;
	constant PadChar = '!'.ord;
	constant EOD = '~'.ord, '>'.ord; 

        my uint8 @a85;
        for $buf32.reverse -> int $n is copy {
            if $n {
                for 0 .. 4 {
                    @a85.unshift: ($n % 85  +  33);
                    $n div= 85;
                }
            }
            else {
                @a85.unshift: NullChar;
           }
        };

        if padding {
            @a85.splice(*-1, 1, PadChar xx 5)
                if @a85.tail == NullChar;
            @a85.pop for 1 .. padding;
        }

        @a85.append: EOD;

        PDF::IO::Blob.new( @a85 );
    }

    multi method decode(Blob $buf, |c) {
	$.decode($buf.Str, |c);
    }
    multi method decode(Str $input, Bool :$eod = False --> PDF::IO::Blob) {

        my Str $str = $input.subst(/\s/, '', :g).subst(/z/, '!!!!', :g);

        if $str.ends-with('~>') {
            $str = $str.chop(2);
        }
        else {
           die "missing end-of-data marker '~>' at end of hexidecimal encoding"
               if $eod
        }

        die "invalid ASCII85 encoded character: {$0.Str.perl}"
            if $str ~~ /(<-[\!..\u\z]>)/;

        my $padding = -$str.codes % 5;
        my $buf = ($str ~ ('u' x $padding)).encode('latin-1');

        my uint32 @buf32;
        @buf32[+$buf div 5 - 1] = 0; # preallocate

        my int $n = -1;
        for $buf.pairs {
            @buf32[++$n] = 0 if .key %% 5;
            (@buf32[$n] *= 85) += .value - 33;
        }

        $buf = pack(@buf32, 32);
        $buf.pop for 1 .. $padding;

        PDF::IO::Blob.new: $buf;
    }

}
