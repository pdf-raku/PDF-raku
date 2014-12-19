#!/usr/bin/env perl6

use Test;
use JSON::Tiny;

use PDF::Basic::Writer;

my $pdf-writer = PDF::Basic::Writer.new;

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

    my $pdf = $pdf-writer.write( |%node );
    is $pdf, $expected-pdf, "serialize {%node.keys}"
        or diag {node => %node}.perl;

}

done;
