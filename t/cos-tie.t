use v6;
use Test;
plan 48;

use PDF::IO::Reader;
use PDF::IO::Writer;
use PDF::IO::Serializer;
use PDF::COS::Array;
use PDF::COS::Dict;
use PDF::COS::Name;
use PDF::COS::Stream;

sub name($name){ PDF::COS::Name.COERCE($name) };

my PDF::IO::Reader $reader .= new();
isa-ok $reader, PDF::IO::Reader;
$reader.open( 't/pdf/pdf.in' );
is-deeply $reader.trailer.reader, $reader, 'trailer reader';
my $root-obj = $reader.trailer<Root>;
is-deeply $root-obj.reader, $reader, 'root object .reader';
is $root-obj.obj-num, 1, 'root object .obj-num';
is $root-obj.gen-num, 0, 'root object .gen-num';
is-deeply $root-obj.ind-ref, 'ind-ref' => [1, 0];
is-deeply $root-obj.link, 'ind-ref' => [1, 0, $reader];

# sanity

ok $root-obj<Type>:exists, 'root object existance';
ok $root-obj<Wtf>:!exists, 'root object non-existance';
lives-ok {$root-obj<Wtf> = 'Yup' }, 'key stantiation - lives';
ok $root-obj<Wtf>:exists, 'key stantiation';
is $root-obj<Wtf>, 'Yup', 'key stantiation';
lives-ok {$root-obj<Wtf>:delete}, 'key deletion - lives';
ok $root-obj<Wtf>:!exists, 'key deletion';

my $type = $root-obj<Type>;
is $type, 'Catalog', '$root-obj<Type>';

# start fetching indirect objects

my $Pages := $root-obj<Pages>;
is $Pages<Type>, 'Pages', 'Pages<Type>';
is-deeply $Pages.reader, $reader, 'root has deref - stickyness';

# force an object to indirect
$Pages<Count> = PDF::COS.coerce: $Pages<Count>;
$Pages<Count>.is-indirect = True;
is $Pages<Count>.obj-num, -1, 'set .is-indirect = True';
$Pages<Count>.is-indirect = False;
ok !($Pages<Count>.obj-num), 'set .is-indirect = False';

my $Kids = $Pages<Kids>;
isa-ok $Kids, Array;
isa-ok $Kids, PDF::COS::Array;
is-deeply $Kids.reader, $reader, 'hash -> array deref - reader stickyness';
my $kid := $Kids[0];
is-deeply $kid.reader, $reader, 'array -> hash deref - reader stickyness';
is $kid<Type>, 'Page', 'Kids[0]<Type>';

ok $Pages<Kids>[0]<Parent> === $Pages, '$Pages<Kids>[0]<Parent> === $Pages';

my $contents = $kid<Contents>;
is $contents.Length, 45, 'contents.Length';
is $contents.encoded, q:to'--END--'.chomp, 'contents.encoded';
BT
/F1 24 Tf
100 100 Td (Hello, world!) Tj
ET
--END--

# demonstrate low level construction of a PDF. First page is copied from an
# input PDF. Second page is constructed from scratch.

my Str $decoded = "BT /F1 24 Tf  100 250 Td (Bye for now!) Tj ET";
my UInt $Length = $decoded.codes;

lives-ok {
    my $Resources = $Pages<Kids>[0]<Resources>;
    my PDF::COS::Dict() $new-page = { :Type(name 'Page'), :MediaBox[0, 0, 420, 595], :$Resources };
    my PDF::COS::Stream() $contents = { :$decoded, :dict{ :$Length } };
    $new-page<Contents> = $contents;
    $new-page<Parent> = $Pages;
    $Pages<Kids>.push: $new-page;
    $Pages<Count> = $Pages<Count> + 1;
    }, 'page addition';

is $contents<Length>, $Length, '$stream<Length> dereference';
is $contents.Length, $Length, '$stream.Length accessor';
$contents<Length>:delete;
ok !$contents.Length.defined, '$stream<Length>:delete propagates to $stream.Length';

$contents = Nil;

my PDF::COS::Dict() $pdf = { :Root{ :Type(name 'Catalog') } };
$pdf<Root><Outlines> = $root-obj<Outlines>;
$pdf<Root><Pages> = $root-obj<Pages>;

my $body = PDF::IO::Serializer.new.body( $pdf );

# write the two page pdf
my $ast = :cos{ :header{ :version(1.2) }, :$body };
my PDF::IO::Writer $writer .= new: :$ast;
ok 't/hello-and-bye.pdf'.IO.spurt( $writer.Blob), 'output 2 page pdf';

use PDF::COS::Tie;
use PDF::COS::Tie::Hash;
use PDF::COS::Tie::Array;

my role HashRole does PDF::COS::Tie::Hash {
    has $.Foo is entry;
}

my role ArrayRole does PDF::COS::Tie::Array {
    has $.Baz is index(0, :default(99));
    has $.Bar is index[1];
}

my PDF::COS::Dict() $h1 = {};
lives-ok { HashRole.COERCE($h1) }, 'tied hash role application';
does-ok $h1, HashRole, 'Hash/Hash application';
$h1.Foo = 42;
is $h1<Foo>, 42, 'tied hash';
is $h1.Foo, 42, 'tied hash accessor';

my PDF::COS::Dict() $h2 = {};
dies-ok { ArrayRole.COERCE($h2) }, 'Hash/Array misapplication';
ok !$h2.does(ArrayRole), 'Hash/Array misapplication';

my PDF::COS::Array() $a1 = [];
lives-ok { ArrayRole.COERCE($a1) }, 'tied array role application';
does-ok $a1, ArrayRole, 'Hash/Hash application';
$a1.Bar = 69;
is $a1[1], 69, 'tied array index';
is $a1.Bar, 69, 'tied array accessor';
is $a1.Baz, 99, 'tied array defaulted accessor';
is $a1[0], Any, 'tied array defaulted index';

my PDF::COS::Array() $a2 = [];
dies-ok { HashRole.COERCE($a2) }, 'Array/Hash misapplication';
ok !$a2.does(HashRole), 'Array/Hash misapplication';

my PDF::COS::Array() $a3 = (1..3).map(* * 10);
isa-ok $a3, PDF::COS::Array, 'coerce array from Seq';
is $a3[2], 30, 'coerce from Seq';

done-testing;
