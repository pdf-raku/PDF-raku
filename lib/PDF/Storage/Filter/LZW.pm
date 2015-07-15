use v6;
# code adapted from http://rosettacode.org/wiki/LZW_compression#Perl_6
use PDF::Storage::Filter::Role::Predictors;

class PDF::Storage::Filter::LZW
    does PDF::Storage::Filter::Role::Predictors {

    # Maintainer's Note: LZW is described in the PDF 1.7 spec
    # in section 3.3.3.

    method encode(Str $input, Bool :$eod, *%params --> Str) {

        my $dict-size = 256;
        my %dictionary = (.chr => .chr for ^$dict-size);

        my Blob $buf = $input.encode('latin-1');
        $buf = $.prediction( $buf, |%params )
            if %params<Predictor>:exists;

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

        $str;
    }

    method decode(Str $input, Bool :$eod, *%params --> Str) {

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

        if %params<Predictor>:exists {
            my Blob $buf = $str.encode('latin-1');
            $buf = $.post-prediction( $buf, |%params );
            $str = $buf.decode('latin-1');
        }

        $str;
    }
}
