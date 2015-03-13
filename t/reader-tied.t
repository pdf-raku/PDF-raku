use v6;
use Test;

use PDF::Reader;
use PDF::Object;

my $reader = PDF::Reader.new(:debug);

$reader.open( 't/pdf/pdf.in' );

my $root-obj = $reader.tied;

isa_ok $root-obj, ::('PDF::Object::Type::Catalog');
is_deeply $root-obj.reader, $reader, 'root object .reader';

# sanity

ok $root-obj<Type>:exists, 'root object existance';
ok $root-obj<Wtf>:!exists, 'root object non-existance';
lives_ok {$root-obj<Wtf> = 'Yup' }, 'key stantiation - lives';
ok $root-obj<Wtf>:exists, 'key stantiation';
is $root-obj<Wtf>, 'Yup', 'key stantiation';
lives_ok {$root-obj<Wtf>:delete}, 'key deletion - lives';
ok $root-obj<Wtf>:!exists, 'key deletion';

my $type = $root-obj<Type>;
is $type, 'Catalog';

my $type-called = $root-obj.Type, 'root object .Type';

# start fetching indirect objects

my $Pages := $root-obj<Pages>;
is $Pages<Type>, 'Pages', 'Pages<Type>';

my $Kids = $Pages<Kids>;
note :$Pages.perl;

my $kid := $Kids[0];
is $kid<Type>, 'Page', 'Kids[0]<Type>';

# see if we can link back to our parent
my $kid-Parent := $kid<Parent>;

is $Pages<Kids>[0]<Parent>.WHERE, $Pages.WHERE, '$Pages<Kids>[0]<Parent> :== $Pages';

done;

