#!/usr/bin/env perl6

use Test;
use JSON::Tiny;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test;
use PDF::Tools::Input;
use PDF::Writer;

my $actions = PDF::Grammar::PDF::Actions.new();

for 't/pdf'.IO.dir.list {

    next unless / [\w|'-']*? '.json'$/;
    my $json-file = ~$_;
    my %ast = %( from-json( $json-file.IO.slurp ) );

    my $pdf-input-file = $json-file.subst( /'.json'$/, '.in' );
    my $pdf-output-file = $json-file.subst( /'.json'$/, '.out' );
    my $input = PDF::Tools::Input.compose( :value($pdf-input-file.IO.open( :r, :enc<latin-1>) ) );
    my $pdf-output = PDF::Writer.new( :$input, :offset(0), :%ast );
    $pdf-output-file.IO.spurt: ~$pdf-output;

    my ($rule) = %ast.keys;
    my %expected = :%ast;
    my $class = PDF::Grammar::PDF;

    PDF::Grammar::Test::parse-tests($class, ~$input, :$rule, :$actions, :suite("[$pdf-input-file]"), :%expected );
    PDF::Grammar::Test::parse-tests($class, ~$pdf-output, :$rule, :$actions, :suite("[$pdf-output-file]"), :%expected );
}

done;
