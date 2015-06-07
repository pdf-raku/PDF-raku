use v6;
use Test;

use PDF::Reader;
use PDF::Object::Dict;
use PDF::Object::Stream;
use PDF::DOM::Catalog;
use PDF::DOM::Page;
use PDF::DOM::Pages;
use PDF::DOM::XObject::Form;
use PDF::DOM::XObject::Image;
use PDF::DOM::Font;
use PDF::Grammar::Test :is-json-equiv;

my $pdf-in = PDF::Reader.new();
$pdf-in.open( 't/pdf/pdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.type, 'PDF', 'loaded type';
is $pdf-in.size, 9, 'loaded size';
isa-ok $pdf-in.root.object, PDF::DOM::Catalog , 'root-obj';
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

my $page = $pdf-in.ind-obj(4, 0).object;
isa-ok $page, PDF::DOM::Page;

my $xobject = $page.to-xobject;
isa-ok $xobject, PDF::DOM::XObject::Form;
is $xobject.decoded, $pdf-in.ind-obj(5, 0).object.encoded, 'xobject encoding';
is-json-equiv $xobject.BBox, $page.MediaBox, 'xobject BBox';
is-json-equiv $xobject.Resources, $page.Resources, 'xobject Resources';

my $new-page = $pdf-in.root.object.Pages.add-page();
isa-ok $new-page, PDF::DOM::Page, 'new page';
my $fm1 = $new-page.register-resource( $xobject );
is $fm1, 'Fm1', 'xobject form name';

my $object2 = PDF::DOM::XObject::Form.new;
my $object3 = PDF::DOM::XObject::Image.new;
my $object4 = PDF::DOM::Font.new;
my $fm2 = $new-page.register-resource( $object2 );
is $fm2, 'Fm2', 'xobject form name';

my $im1 = $new-page.register-resource( $object3 );
is $im1, 'Im1', 'xobject form name';

my $f1 = $new-page.register-resource( $object4 );
is $f1, 'F1', 'font name';

my $fm1-again = $new-page.register-resource( $xobject );
is $fm1-again, $fm1, 'xobject form name, reregistered';

is-json-equiv $new-page<Resources><XObject>, { :Fm1($xobject), :Fm2($object2), :Im1($object3) }, 'Resource XObject content';
is-json-equiv $new-page<Resources><Font>, { :F1($object4) }, 'Resource Font content';
done;
