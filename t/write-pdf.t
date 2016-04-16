#!/usr/bin/env perl6

use Test;
use JSON::Fast;

use PDF::Grammar::Doc;
use PDF::Grammar::Doc::Actions;
use PDF::Grammar::Test;
use PDF::Storage::Input;
use PDF::Writer;

my $actions = PDF::Grammar::Doc::Actions.new();

for 't/pdf'.IO.dir.list.sort {

    next unless / [\w|'-']*? '.json'$/;
    my $json-file = ~$_;
    my %ast = from-json( $json-file.IO.slurp );

    my $pdf-input-file = $json-file.subst( /'.json'$/, '.in' );
    next unless $pdf-input-file.IO.e;
    my $pdf-output-file = $json-file.subst( /'.json'$/, '.out' );
    my $input = PDF::Storage::Input.coerce( $pdf-input-file.IO );
    my $pdf-output = PDF::Writer.new( :$input, :offset(0), :%ast );
    $pdf-output-file.IO.spurt( ~$pdf-output, :enc<latin-1> );

    my ($rule) = %ast.keys;
    my %expected = :%ast;

    my $class = PDF::Grammar::Doc;

    PDF::Grammar::Test::parse-tests($class, ~$input, :$rule, :$actions, :suite("[$pdf-input-file]"), :%expected );

    my $json-output-file = $pdf-output-file ~ '.json';
    my $output = PDF::Storage::Input.coerce( $pdf-output-file.IO );
    PDF::Grammar::Test::parse-tests($class, ~$output, :$rule, :$actions, :suite("[$pdf-output-file]"), :%expected );
}

done-testing;
