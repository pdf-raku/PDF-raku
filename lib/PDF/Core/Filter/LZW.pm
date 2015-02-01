use v6;
# code adapted from http://rosettacode.org/wiki/LZW_compression#Perl_6
use PDF::Core::Filter::Mixin::Predictors;

class PDF::Core::Filter::LZW
    is PDF::Core::Filter::Mixin::Predictors; # to get predictor methods

# Maintainer's Note: LZW is described in the PDF 1.7 spec
# in section 3.3.3.

method encode(Str $input, Bool :$eod, *%params --> Str) {

    my $dict-size = 256;
    my %dictionary = (.chr => .chr for ^$dict-size);

    my $buf = $input.encode('latin-1');
    $buf = $.prediction( $buf, |%params )
        if %params<Predictor>:exists;

    my $w = "";
    my $str = join '', gather {
        for $buf.list {
            my $c = .chr;
            my $wc = $w ~ $c;
            if %dictionary{$wc}:exists { $w = $wc }
            else {
                take %dictionary{$w};
                %dictionary{$wc} = +%dictionary;
                $w = $c;
            }
        }
 
        take %dictionary{$w} if $w.chars;
    }

    $str;
}

method decode(Str $input, Bool :$eod, *%params --> Str) {

    my $dict-size = 256;
    my %dictionary = (.chr => .chr for ^$dict-size);
    my @compressed = $input.comb;
 
    my $w = shift @compressed;
    my $str = join '', gather {
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
        my $buf = $str.encode('latin-1');
        $buf = $.post-prediction( $buf, |%params );
        $str = $buf.decode('latin-1');
    }

    $str;
}
