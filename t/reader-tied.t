use v6;
use Test;

use PDF::Reader;

my $reader = PDF::Reader.new(:debug);

$reader.open( 't/pdf/pdf.in' );

my $root-obj = $reader.tie;

isa_ok $root-obj, ::('PDF::Object::Type::Catalog');
is_deeply $root-obj.reader, $reader, 'root object .reader';
is $root-obj.obj-num, 1, 'root object .obj-num';
is $root-obj.gen-num, 0, 'root object .gen-num';

ok $root-obj<Type>:exists, 'root object existance';
ok $root-obj<Wtf>:!exists, 'root object non-existance';
my $type = $root-obj<Type>;
is $type, 'Catalog';

my $type-called = $root-obj.Type, 'root object .Type';

done;

