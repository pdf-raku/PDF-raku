use v6;
use Test;

use PDF::Reader;
use PDF::Object::Dict;
use PDF::Object::Content;
use PDF::Object::Type::Catalog;
use PDF::Object::Type::Page;
use PDF::Object::Type::Pages;
use PDF::Object::Type::XObject::Form;
use PDF::Object::Type::XObject::Image;
use PDF::Object::Type::Font;
use PDF::Grammar::Test :is-json-equiv;

my $pdf-in = PDF::Reader.new();

$pdf-in.open( 't/pdf/pdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.type, 'PDF', 'loaded type';
is $pdf-in.size, 9, 'loaded size';
isa_ok $pdf-in.root.object, PDF::Object::Type::Catalog , 'root-obj';
is $pdf-in.root.obj-num, 1, 'root-obj.obj-num';
isa_ok $pdf-in.ind-obj(3, 0).object, PDF::Object::Dict, 'fetch via index';
isa_ok $pdf-in.ind-obj(5, 0).object, PDF::Object::Content, 'fetch via index';
is $pdf-in.ind-obj(5, 0).object.encoded, "BT\n/F1 24 Tf\n100 100 Td (Hello, world!) Tj\nET", 'stream content';

my $page = $pdf-in.ind-obj(4, 0).object;
isa_ok $page, PDF::Object::Type::Page;

my $xobject = $page.to-xobject;
isa_ok $xobject, PDF::Object::Type::XObject::Form;
is $xobject.decoded, $pdf-in.ind-obj(5, 0).object.encoded, 'xobject encoding';
is-json-equiv $xobject.BBox, $page.MediaBox, 'xobject BBox';
is-json-equiv $xobject.Resources, $page.Resources, 'xobject Resources';

my $new-page = $pdf-in.root.object.Pages.add-page();
isa_ok $new-page, PDF::Object::Type::Page, 'new page';
my $fm1 = $new-page.register-resource( $xobject );
is $fm1, 'Fm1', 'xobject form name';

my $object2 = PDF::Object::Type::XObject::Form.new;
my $object3 = PDF::Object::Type::XObject::Image.new;
my $object4 = PDF::Object::Type::Font.new;
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
