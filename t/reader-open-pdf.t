use v6;
use Test;

use PDF::Reader;
use PDF::Object::Dict;
use PDF::Object::Stream;
use PDF::Object::Type::Catalog;

my $pdf-in = PDF::Reader.new();

$pdf-in.open( 't/pdf/pdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.type, 'PDF', 'loaded type';
is $pdf-in.size, 9, 'loaded size';
isa_ok $pdf-in.root.object, PDF::Object::Type::Catalog , 'root-obj';
is $pdf-in.root.obj-num, 1, 'root-obj.obj-num';
isa_ok $pdf-in.ind-obj(3, 0).object, PDF::Object::Dict, 'fetch via index';
isa_ok $pdf-in.ind-obj(5, 0).object, PDF::Object::Stream, 'fetch via index';
is $pdf-in.ind-obj(5, 0).object.encoded, "BT\n/F1 24 Tf\n100 100 Td (Hello, world!) Tj\nET", 'stream content';

done;

