use v6;
use Test;

use PDF::Reader;
use PDF::Object::Dict;
use PDF::Object::Stream;
use PDF::Object::Type::Catalog;
use PDF::Object::Type::Page;
use PDF::Object::Type::XObject::Form;

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

my $page = $pdf-in.ind-obj(4, 0).object;
isa_ok $page, PDF::Object::Type::Page;

my $xobject = $page.to-xobject;
isa_ok $xobject, PDF::Object::Type::XObject::Form;
is $xobject.decoded, $pdf-in.ind-obj(5, 0).object.encoded, 'xobject encoding';
temp $pdf-in.auto-deref = False;
is_deeply $xobject.BBox, $page.MediaBox, 'xobject BBox';
is_deeply $xobject.Resources, $page.Resources, 'xobject Resources';
done;

