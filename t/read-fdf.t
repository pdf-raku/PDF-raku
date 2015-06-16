use v6;
use Test;

use PDF::Reader;
use PDF::Object::Dict;
use PDF::Object::Stream;

my $pdf-in = PDF::Reader.new();

$pdf-in.open( 't/pdf/pdf-fdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.type, 'FDF', 'loaded type';
isa-ok $pdf-in.root.object, PDF::Object , 'root-obj';
is $pdf-in.root.obj-num, 1, 'root-obj.obj-num';
isa-ok $pdf-in.ind-obj(1, 0).object, PDF::Object::Dict, 'fetch via index';

done;
