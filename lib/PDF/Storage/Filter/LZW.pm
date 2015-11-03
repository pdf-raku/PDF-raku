use v6;
# code adapted from http://rosettacode.org/wiki/LZW_compression#Perl_6
use PDF::Storage::Filter::Predictors;

class PDF::Storage::Filter::LZW
    does PDF::Storage::Filter::Predictors {

    # Maintainer's Note: LZW is described in the PDF 1.7 spec
    # in section 3.3.3.
    use PDF::Storage::Blob;

    multi method encode(Str $input, |c) {
	$.encode($input.encode("latin-1"), |c);
    }
    multi method encode(Blob $buf is copy, Bool :$eod, :$Predictor, |c --> Blob) {

        my $dict-size = 256;
        my %dictionary = (.chr => .chr for ^$dict-size);

        $buf = $.prediction( $buf, :$Predictor, |c )
            if $Predictor;

        my Str $w = "";
        my Str $str = join( '', gather {
            for $buf.list {
                my Str $c = .chr;
                my Str $wc = $w ~ $c;
                if %dictionary{$wc}:exists { $w = $wc }
                else {
                    take %dictionary{$w};
                    %dictionary{$wc} = +%dictionary;
                    $w = $c;
                }
            }

            take %dictionary{$w}
	        if %dictionary{$w}:exists;
        });

        PDF::Storage::Blob.new: $str.encode('latin-1');
    }

    multi method decode(Str $input, |c) {
	$.decode($input.encode("latin-1"), |c);
    }
    multi method decode(Blob $buf, Bool :$eod, :$Predictor, |c --> Blob) is default {

        my $dict-size = 256;
        my @dictionary = map {[$_,]}, (0 .. $dict-size);
        my uint8 @compressed = $buf.list;

        my $w = shift @compressed;
        my uint8 @buf = flat gather {
            take $w;
            for @compressed -> $k {
                my $entry = @dictionary[$k];
                take @dictionary[$k].Slip;
		my @next = flat @$w, $w[0];
                @dictionary[$dict-size++] = @next;
                $w = $entry;
            }
        };

	my $out = buf8.new: @buf;

        if $Predictor {
            $out = $.post-prediction( $out, :$Predictor, |c );
        }

        PDF::Storage::Blob.new: $out;
    }
}
