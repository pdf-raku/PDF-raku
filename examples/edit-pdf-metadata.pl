#!/usr/bin/env perl6
use v6;

use PDF;
use File::Temp;
use JSON::Fast;

sub MAIN(Str $infile, Str $outfile?, Str :$editor) {

    die "Input file '$infile' can't be read\n"
        unless $infile.IO.r;

    my $pdf = PDF.open: $infile;
    my ($temp) = tempfile;
    my %info = $pdf.Info // {};
    $temp.IO.spurt: to-json( %info );

    with $editor // %*ENV<EDITOR> {
        run( $_, $temp );
    }
    else {
        die "No --editor option, and no EDITOR environment variable set.\n";
    }

    $pdf.Info = from-json( $temp.IO.slurp );

    with $outfile {
        $pdf.save-as: $_;
    }
    else {
        $pdf.update;
    }
}
