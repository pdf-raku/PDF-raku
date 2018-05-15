use v6;
use Test;
plan 40;

use PDF::Reader;
use PDF::Writer;
use PDF::IO::Serializer;
use PDF::COS;
use PDF::COS::Array;

sub name($name){ PDF::COS.coerce(:$name) };

my $reader = PDF::Reader.new();
isa-ok $reader, PDF::Reader;
$reader.open( 't/pdf/pdf.in' );
is-deeply $reader.trailer.reader, $reader, 'trailer reader';
my $root-obj = $reader.trailer<Root>;
is-deeply $root-obj.reader, $reader, 'root object .reader';
is $root-obj.obj-num, 1, 'root object .obj-num';
is $root-obj.gen-num, 0, 'root object .gen-num';

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

is $Pages<Kids>[0]<Parent>.WHERE, $Pages.WHERE, '$Pages<Kids>[0]<Parent>.WHERE == $Pages.WHERE';

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
    my $new-page = PDF::COS.coerce: { :Type(name 'Page'), :MediaBox[0, 0, 420, 595], :$Resources };
    my $contents = PDF::COS.coerce( :stream{ :$decoded, :dict{ :$Length } } );
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

my $pdf = PDF::COS.coerce: { :Root{ :Type(name 'Catalog') } };
$pdf<Root><Outlines> = $root-obj<Outlines>;
$pdf<Root><Pages> = $root-obj<Pages>;

my $body = PDF::IO::Serializer.new.body( $pdf );

# write the two page pdf
my $ast = :cos{ :header{ :version(1.2) }, :$body };
my $writer = PDF::Writer.new: :$ast;
ok 't/hello-and-bye.pdf'.IO.spurt( $writer.Blob), 'output 2 page pdf';

use PDF::COS::Tie;
use PDF::COS::Tie::Hash;
use PDF::COS::Tie::Array;

sub warns-like(&code, $ex-type, $desc = 'warning') {
    my $ex;
    my Bool $w = False;
    &code();
    CONTROL {
	default {
	    $ex = $_;
	    $w = True;
	}
    }
    if $w {
        isa-ok $ex, $ex-type, $desc;
    }
    else {
        flunk $desc;
        diag "no warnings found";
    }
}

my role HashRole does PDF::COS::Tie::Hash {
    has $.Foo is entry;
}

my role ArrayRole does PDF::COS::Tie::Array {
    has $.Bar is index[1];
}

my $h1 = PDF::COS.coerce: {};
lives-ok { PDF::COS.coerce($h1, HashRole) }, 'tied hash role application';
does-ok $h1, HashRole, 'Hash/Hash application';
$h1.Foo = 42;
is $h1<Foo>, 42, 'tied hash';
is $h1.Foo, 42, 'tied hash accessor';

my $h2 = PDF::COS.coerce: {};
warns-like { PDF::COS.coerce($h2, ArrayRole) }, ::('X::PDF::Coerce'), 'Hash/Array misapplication';
ok !$h2.does(ArrayRole), 'Hash/Array misapplication';

my $a1 = PDF::COS.coerce: [];
lives-ok { PDF::COS.coerce($a1, ArrayRole) }, 'tied array role application';
does-ok $a1, ArrayRole, 'Hash/Hash application';
$a1.Bar = 69;
is $a1[1], 69, 'tied array accessor';
is $a1.Bar, 69, 'tied array accessor';

my $a2 = PDF::COS.coerce: [];
warns-like { PDF::COS.coerce($a2, HashRole) }, ::('X::PDF::Coerce'), 'Array/Hash misapplication';
ok !$a2.does(HashRole), 'Array/Hash misapplication';

done-testing;
