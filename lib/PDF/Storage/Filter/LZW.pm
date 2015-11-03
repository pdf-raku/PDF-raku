use v6;
# code adapted from http://rosettacode.org/wiki/LZW_compression#Perl_6
use PDF::Storage::Filter::Predictors;

class PDF::Storage::Filter::LZW
    does PDF::Storage::Filter::Predictors {

    # Maintainer's Note: LZW is described in the PDF 1.7 spec
    # in section 3.3.3.
    use PDF::Storage::Blob;

    multi method encode(Blob $input, |c) {
	$.encode($input.decode("latin-1"), |c);
    }
    multi method encode(Str $input, Bool :$eod, :$Predictor, |c --> Blob) {

        my $dict-size = 256;
        my %dictionary = (.chr => .chr for ^$dict-size);

        my Blob $buf = $input.encode('latin-1');
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

            take %dictionary{$w} if $w.chars;
        });

        PDF::Storage::Blob.new: $str.encode('latin-1');
    }

    multi method decode(Blob $input, |c) {
	$.decode($input.decode("latin-1"), |c);
    }
    multi method decode(Str $input, Bool :$eod, :$Predictor, |c --> Blob) is default {

        my $dict-size = 256;
        my %dictionary = (.chr => .chr for ^$dict-size);
        my @compressed = $input.comb;

        my Str $w = shift @compressed;
        my Str $str = join '', gather {
            take $w;
            for @compressed -> $k {
                my $entry;
                if %dictionary{$k}:exists { take $entry = %dictionary{$k} }
                elsif $k == $dict-size    { take $entry = $w ~ $w.substr(0,1) }
                else                      { die "Bad compressed k: $k" }

                %dictionary{$dict-size++} = $w ~ $entry.substr(0,1);
                $w = $entry;
            }
        };

        if $Predictor {
            my Blob $buf = $str.encode('latin-1');
            $buf = $.post-prediction( $buf, :$Predictor, |c );
            $str = $buf.decode('latin-1');
        }

        PDF::Storage::Blob.new: $str.encode('latin-1');
    }
}
