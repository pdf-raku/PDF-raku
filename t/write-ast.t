#!/usr/bin/env perl6

use Test;
use JSON::Tiny;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Writer;
use lib '.';
use t::Object :to-obj;

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

    if my $to-obj = $test<to-obj> {
        my $perl = to-obj( |%ast );
        is-json-equiv $perl, $to-obj, "to-obj {%ast.keys.sort}"
            or diag :%ast.perl;
    }
}

done;
