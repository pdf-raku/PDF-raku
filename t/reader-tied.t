use v6;
use Test;

use PDF::Reader;
use PDF::Object;

my $reader = PDF::Reader.new(:debug);

$reader.open( 't/pdf/pdf.in' );

my $root-obj = $reader.tied;
isa_ok $root-obj, ::('PDF::Object::Type::Catalog');
is_deeply $root-obj.reader, $reader, 'root object .reader';
is $root-obj.obj-num, 1, 'root object .obj-num';
is $root-obj.gen-num, 0, 'root object .gen-num';

# sanity

ok $root-obj<Type>:exists, 'root object existance';
ok $root-obj<Wtf>:!exists, 'root object non-existance';
lives_ok {$root-obj<Wtf> = 'Yup' }, 'key stantiation - lives';
ok $root-obj<Wtf>:exists, 'key stantiation';
is $root-obj<Wtf>, 'Yup', 'key stantiation';
lives_ok {$root-obj<Wtf>:delete}, 'key deletion - lives';
ok $root-obj<Wtf>:!exists, 'key deletion';

my $type = $root-obj<Type>;
is $type, 'Catalog', '$root-obj<Type>';

# start fetching indirect objects

my $Pages := $root-obj<Pages>;
is $Pages<Type>, 'Pages', 'Pages<Type>';

my $Kids = $Pages<Kids>;

my $kid := $Kids[0];
is $kid<Type>, 'Page', 'Kids[0]<Type>';

is $Pages<Kids>[0]<Parent>.WHERE, $Pages.WHERE, '$Pages<Kids>[0]<Parent>.WHERE == $Pages.WHERE';

my $contents = $kid<Contents>;
is $contents.Length, 45, 'contents.Length';
is $contents.encoded, q:to'--END--'.chomp, 'contents.encoded';
BT
/F1 24 Tf
100 100 Td (Hello, world!) Tj
ET
--END--

lives_ok {
    my $new-page = PDF::Object.compose( :dict{ :Type(PDF::Object.compose(:name<Page>)), :MediaBox[0, 0, 420, 595] } );
my $contents = PDF::Object.compose( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Bye for now!) Tj ET" ), :dict{ :Length(46) } } );
    $new-page<Contents> = $contents;
    $Pages<Kids>.push: $new-page;
    $Pages<Count> = $Pages<Count> + 1;
    }, 'page addition';

done;
