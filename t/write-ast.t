#!/usr/bin/env perl6

use Test;
use JSON::Tiny;

use PDF::Writer;

my $pdf-writer = PDF::Writer.new;

for 't/write-ast.json'.IO.lines {

    next if .substr(0,2) eq '//';

    my $test = from-json($_);
    my $pdf = $test<pdf>;
    my %node = %( $test<ast> );
    my $opt = $test<opt> // {};

    if my $skip = $opt<skip> {
        skip $skip;
        next;
    }

    is $pdf-writer.write( |%node ), $pdf, "serialize {%node.keys} to: $pdf"
        or diag {node => %node}.perl;

}

done;
