#!/usr/bin/env perl6

use Test;
use JSON::Tiny;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test;
use PDF::Writer;

my $actions = PDF::Grammar::PDF::Actions.new();
my $pdf-writer = PDF::Writer.new;

for 't/pdf'.IO.dir.list {

    next unless /'pdf-' \w+ '.json'$/;
    my $json-file = ~$_;
    my $pdf-data = from-json( $json-file.IO.slurp );
    my $pdf-input-file = $json-file.subst( /'.json'$/, '.dat' );
    my $pdf-input = $pdf-input-file.IO.slurp;

    my $pdf-output = $pdf-writer.write( |%$pdf-data );

    my ($rule) = $pdf-data.keys;
    my %expected = ast => $pdf-data{$rule};
    my $class = PDF::Grammar::PDF;

    PDF::Grammar::Test::parse-tests($class, $pdf-input, :$rule, :$actions, :suite('pdf load'), :%expected );
    PDF::Grammar::Test::parse-tests($class, $pdf-output, :$rule, :$actions, :suite('pdf write'), :%expected );

}

done;
