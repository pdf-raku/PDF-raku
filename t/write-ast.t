#!/usr/bin/env raku

use Test;
use JSON::Fast;
use PDF::Grammar::Test :is-json-equiv;
use PDF::IO::Writer;

is PDF::IO::Writer.new.write('array' => [ :real(0.31415926e0), :real(1.3e-17), :real(0.00000000), :real(0e0), :int(1), :null(Any) ]), '[ 0.31416 0 0 0 1 null ]', 'AST - old format';

is PDF::IO::Writer.new.write('array' => [ 0.31415926e0, 1.3e-17, 0.00000000, 0e0, 1, Any ]), '[ 0.31416 0 0 0 1 null ]', 'AST - lite';

for 't/write-ast.json'.IO.lines {

    next if .substr(0,2) eq '//';

    my $test = from-json($_);
    my $expected-pdf = $test<pdf>;
    my %ast = $test<ast>;
    my $opt = $test<opt> // {};

    if my $skip = $opt<skip> {
        skip $skip;
        next;
    }

    my PDF::IO::Writer $pdf-data .= new( :%ast );
    is-json-equiv ~$pdf-data, $expected-pdf, "write {%ast.keys.sort}"
        or diag :%ast.raku;
}

enum ( :Heydər("Heydər Əliyev") );
is PDF::IO::Writer.write-name(Heydər), '/Heyd#c9#99r#20#c6#8fliyev', 'writer enum name (issue #29)';

done-testing;
