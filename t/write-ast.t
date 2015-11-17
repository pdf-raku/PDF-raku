#!/usr/bin/env perl6

use Test;
use JSON::Fast;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Writer;

is PDF::Writer.new.write(:array[ :real(0.31415926e0), :real(1.3e-17), :real(0.00000000), :real(0e0), :real(1) ]), '[ 0.31416 0 0 0 1 ]';

for 't/write-ast.json'.IO.lines {

    next if .substr(0,2) eq '//';

    my $test = from-json($_);
    my $expected-pdf = $test<pdf>;
    my %ast = %( $test<ast> );
    my $opt = $test<opt> // {};

    if my $skip = $opt<skip> {
        skip $skip;
        next;
    }

    my $pdf-data = PDF::Writer.new( :%ast );
    is-json-equiv ~$pdf-data, $expected-pdf, "write {%ast.keys.sort}"
        or diag :%ast.perl;
}

done-testing;
