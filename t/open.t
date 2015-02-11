use v6;
use Test;

use PDF::Tools::Reader;
use PDF::Tools::IndObj::Catalog;
use PDF::Tools::IndObj::Dict;
use PDF::Tools::IndObj::Stream;

my $pdf-in = PDF::Tools::Reader.new(:debug);

$pdf-in.open( 't/pdf/pdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
isa_ok $pdf-in.root-obj, PDF::Tools::IndObj::Catalog , 'root-obj';
is $pdf-in.root-obj.obj-num, 1, 'root-obj.obj-num';
isa_ok $pdf-in.obj(3, 0), PDF::Tools::IndObj::Dict, 'fetch via index';
isa_ok $pdf-in.obj(5, 0), PDF::Tools::IndObj::Stream, 'fetch via index';
is $pdf-in.obj(5, 0).encoded, "BT\n/F1 24 Tf\n100 100 Td (Hello, world!) Tj\nET", 'stream content';

done;

