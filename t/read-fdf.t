use v6;
use Test;
plan 10;

use PDF::IO::Reader;
use PDF::COS::Dict;

my PDF::IO::Reader $pdf-in .= new();

$pdf-in.open( 't/pdf/pdf-fdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.type, 'FDF', 'loaded type';
my $trailer = $pdf-in.trailer<Root>;
isa-ok $trailer, PDF::COS::Dict, 'root-obj';
is $trailer.obj-num, 1, 'root-obj.obj-num';
isa-ok $pdf-in.ind-obj(1, 0).object, PDF::COS::Dict, 'fetch via index';

isa-ok $trailer<FDF>, Hash, '$trailer<FDF>';

is $trailer<FDF><F>, 'Document.pdf', '$trailer<FDF><F>';

isa-ok $trailer<FDF><Fields>, Array, '$trailer<FDF><Fields>';
is $trailer<FDF><Fields>[1]<T>, 'City', '$trailer<FDF><Fields>[1]<T>';

lives-ok {$pdf-in.save-as('t/pdf/pdf-fdf.out')}, 'save-as() - lives';

done-testing;

