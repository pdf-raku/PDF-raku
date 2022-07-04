use v6;
use Test;
plan 20;

use PDF::IO::Reader;
use PDF::COS::Dict;
use PDF::COS::Stream;
use PDF::Grammar::Test :is-json-equiv;

my PDF::IO::Reader $pdf-in .= new();
$pdf-in.open: 't/pdf/pdf.in';

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.type, 'PDF', 'loaded type';
is $pdf-in.size, 9, 'loaded size';
is $pdf-in.trailer<Root>.obj-num, 1, 'root-obj.obj-num';
isa-ok $pdf-in.ind-obj(3, 0).object, PDF::COS::Dict, 'fetch via index';
isa-ok $pdf-in.ind-obj(5, 0).object, PDF::COS::Stream, 'fetch via index';
is $pdf-in.ind-obj(5, 0).object.encoded, "BT\n/F1 24 Tf\n100 100 Td (Hello, world!) Tj\nET", 'stream content';

my $ast = $pdf-in.ast: :rebuild;
is-json-equiv $ast<cos><header>, {:type<PDF>, :version(1.2)}, '$ast header';
is +$ast<cos><body>, 1, 'single body';
is +$ast<cos><body>[0]<objects>, 7, '$ast objects';
is-json-equiv $ast<cos><body>[0]<objects>[0], (:ind-obj([1, 0, :dict({:Outlines(:ind-ref([2, 0])), :Pages(:ind-ref([3, 0])), :Type(:name("Catalog"))})])), '$ast<body><objects>[0]';
is-json-equiv $ast<cos><body>[0]<trailer>, (:dict({:Root(:ind-ref([1, 0])), :Size(8)})), '$ast trailer';

my PDF::IO::Reader $pdf-repaired .= new();
$pdf-repaired.open: 't/pdf/pdf.in', :repair;
is-deeply $pdf-repaired.ast( :rebuild ), $ast, '$reader.open( :repair )';

$pdf-in.save-as: 'tmp/pdf-rewritten.json', :rebuild ;
my PDF::IO::Reader $pdf-json .= new();
$pdf-json.open: 'tmp/pdf-rewritten.json' ;
my $json-ast = $pdf-json.ast: :rebuild;
is-json-equiv $json-ast, $ast, '$reader.open( "tmp/pdf-rewritten.json" )';

$pdf-json.recompress: :compress;
$pdf-json.save-as: 'tmp/pdf-compressed.pdf';
my PDF::IO::Reader $pdf-compressed .= new();
$pdf-compressed.open: 'tmp/pdf-compressed.pdf';
$ast = $pdf-compressed.ast;
my $stream = $ast<cos><body>[0]<objects>.first({ .key eq 'ind-obj' && .value[2].key eq 'stream'});
ok $stream.defined, 'got stream';
is-deeply $stream.value[2]<stream><dict><Filter><name>, 'FlateDecode', 'stream is compressed';

# load from a String
use PDF::IO::Str;
my Str $value = 't/pdf/pdf.in'.IO.slurp(:bin).decode: 'latin-1';
my PDF::IO::Str $input-str .= new( :$value );
my PDF::IO::Reader $pdf-str .= new;
$pdf-str.open: $input-str;
is $pdf-str.version, 1.2, 'str - loaded version';
is $pdf-str.type, 'PDF', 'str - loaded type';
is $pdf-str.size, 9, 'str - loaded size';
is $pdf-str.trailer<Root>.obj-num, 1, 'root-obj.obj-num';

done-testing;
