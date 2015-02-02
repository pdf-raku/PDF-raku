#!/usr/bin/env perl6

use Test;
use JSON::Tiny;

use PDF::Tools;
use PDF::Tools::Util :unbox;

my $pdf = PDF::Tools.new;

for 't/write-ast.json'.IO.lines {

    next if .substr(0,2) eq '//';

    my $test = from-json($_);
    my $expected-pdf = $test<pdf>;
    my %node = %( $test<ast> );
    my $opt = $test<opt> // {};

    if my $skip = $opt<skip> {
        skip $skip;
        next;
    }

    my $pdf-data = $pdf.write( |%node );
    is $pdf-data, $expected-pdf, "serialize {%node.keys}"
        or diag {node => %node}.perl;

    if my $unboxed = $test<unboxed> {
        my $perl = unbox( |%node );
        is_deeply $perl, $unboxed, "unboxed {%node.keys}"
            or diag {node => %node}.perl;
    }

}

done;
