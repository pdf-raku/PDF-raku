#!/usr/bin/env perl6

use Test;
use JSON::Fast;

use PDF::Grammar::COS;
use PDF::Grammar::COS::Actions;
use PDF::Grammar::Test;
use PDF::IO;
use PDF::Writer;

unless $*PERL.compiler.version >= v2017.04 {
    plan 0;
    skip-rest "Rakudo/JSON < 2017.04 incompatibilty";
    exit;
}

my PDF::Grammar::COS::Actions $actions .= new();

for 't/pdf'.IO.dir.grep(/ [\w|'-']*? '.json'$/).sort -> $json-file {

    my %ast = from-json( $json-file.IO.slurp );

    my $pdf-input-file = $json-file.subst( /'.json'$/, '.in' );
    next unless $pdf-input-file.IO.e;
    my $pdf-output-file = $json-file.subst( /'.json'$/, '.out' );
    my PDF::IO $input .= coerce( $pdf-input-file.IO );
    my PDF::Writer $pdf-output .= new( :$input, :offset(0), :%ast );
    $pdf-output-file.IO.spurt: $pdf-output.Blob;

    my ($rule) = %ast.keys;
    my %expected = :%ast;

    my $class = PDF::Grammar::COS;

    PDF::Grammar::Test::parse-tests($class, ~$input, :$rule, :$actions, :suite("[$pdf-input-file]"), :%expected );

    my $json-output-file = $pdf-output-file ~ '.json';
    my PDF::IO $output .= coerce( $pdf-output-file.IO );
    PDF::Grammar::Test::parse-tests($class, ~$output, :$rule, :$actions, :suite("[$pdf-output-file]"), :%expected );
}

done-testing;
