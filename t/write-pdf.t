#!/usr/bin/env raku

use Test;
use JSON::Fast;

use PDF::Grammar::COS;
use PDF::Grammar::COS::Actions;
use PDF::Grammar::Test;
use PDF::IO;
use PDF::IO::Writer;

my PDF::Grammar::COS::Actions $actions .= new();

for 't/pdf'.IO.dir.grep(/ [\w|'-']*? '.json'$/).sort -> $json-file {

    my %ast = from-json( $json-file.IO.slurp );

    my $pdf-input-file = $json-file.subst( /'.json'$/, '.in' );
    next unless $pdf-input-file.IO.e;
    my $pdf-output-file = $json-file.subst( /'.json'$/, '.out' );
    my PDF::IO() $input = $pdf-input-file.IO;
    my PDF::IO::Writer $pdf-output .= new( :$input, :offset(0), :%ast );
    $pdf-output-file.IO.spurt: $pdf-output.Blob;

    my $rule = %ast.keys.head;
    my %expected = :%ast;

    my PDF::Grammar::COS $class;

    PDF::Grammar::Test::parse-tests($class, ~$input, :$rule, :$actions, :suite("[$pdf-input-file]"), :%expected );

    my $json-output-file = $pdf-output-file ~ '.json';
    my PDF::IO() $output = $pdf-output-file.IO;
    PDF::Grammar::Test::parse-tests($class, ~$output, :$rule, :$actions, :suite("[$pdf-output-file]"), :%expected );
}

done-testing;
