#!/usr/bin/env perl6

use Test;
use JSON::Tiny;

use PDF::Tools::Writer;
use PDF::Tools::Util :unbox;

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

    my $pdf-data = PDF::Tools::Writer.new( :%ast );
    is_deeply ~$pdf-data, $expected-pdf, "serialize {%ast.keys.sort}"
        or diag :%ast.perl;

    if my $unboxed = $test<unboxed> {
        my $perl = unbox( |%ast );
        is_deeply $perl, $unboxed, "unboxed {%ast.keys.sort}"
            or diag :%ast.perl;
    }
}

done;
