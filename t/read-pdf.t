use v6;
use Test;

use PDF::Reader;
use PDF::Object::Dict;
use PDF::Object::Stream;
use PDF::Grammar::Test :is-json-equiv;

my $pdf-in = PDF::Reader.new();
$pdf-in.open( 't/pdf/pdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.type, 'PDF', 'loaded type';
is $pdf-in.size, 9, 'loaded size';
is $pdf-in.root.obj-num, 1, 'root-obj.obj-num';
isa-ok $pdf-in.ind-obj(3, 0).object, PDF::Object::Dict, 'fetch via index';
isa-ok $pdf-in.ind-obj(5, 0).object, PDF::Object::Stream, 'fetch via index';
is $pdf-in.ind-obj(5, 0).object.encoded, "BT\n/F1 24 Tf\n100 100 Td (Hello, world!) Tj\nET", 'stream content';

my $ast = $pdf-in.ast( :rebuild );
is-json-equiv $ast<pdf><header>, {:type<PDF>, :version(1.2)}, '$ast header';
is +$ast<pdf><body>, 1, 'single body';
is +$ast<pdf><body>[0]<objects>, 7, '$ast objects';
is-json-equiv $ast<pdf><body>[0]<objects>[0], (:ind-obj([1, 0, :dict({:Outlines(:ind-ref([2, 0])), :Pages(:ind-ref([3, 0])), :Type(:name("Catalog"))})])), '$ast<body><objects>[0]';
is-json-equiv $ast<pdf><body>[0]<trailer>, (:dict({:Root(:ind-ref([1, 0])), :Size(:int(8))})), '$ast trailer';

my $pdf-repaired = PDF::Reader.new();
$pdf-repaired.open( 't/pdf/pdf.in', :repair );
is-deeply $pdf-repaired.ast( :rebuild ), $ast, '$reader.open( :repair )';

my $pdf-json = PDF::Reader.new();
$pdf-in.write( 't/pdf/pdf-rewritten.json', :rebuild );
$pdf-json.open( 't/pdf/pdf-rewritten.json' );
is-deeply $pdf-json.ast( :rebuild ), $ast, '$reader.open( "pdf.json" )';

done;