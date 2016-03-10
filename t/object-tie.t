use v6;
use Test;

use PDF::Reader;
use PDF::Writer;
use PDF::Storage::Serializer;
use PDF::DAO;

sub prefix:</>($name){ PDF::DAO.coerce(:$name) };

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
isa-ok $Kids, PDF::DAO::Array;
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
    my $new-page = PDF::DAO.coerce: { :Type(/'Page'), :MediaBox[0, 0, 420, 595], :$Resources };
    my $contents = PDF::DAO.coerce( :stream{ :$decoded, :dict{ :$Length } } );
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

my $doc = PDF::DAO.coerce: { :Root{ :Type(/'Catalog') } };
$doc<Root><Outlines> = $root-obj<Outlines>;
$doc<Root><Pages> = $root-obj<Pages>;

my $body = PDF::Storage::Serializer.new.body( $doc );

# write the two page pdf
my $ast = :pdf{ :version(1.2), :$body };
my $writer = PDF::Writer.new( );
ok 't/hello-and-bye.pdf'.IO.spurt( $writer.write($ast), :enc<latin-1> ), 'output 2 page pdf';

use PDF::DAO::Tie;
use PDF::DAO::Tie::Hash;
use PDF::DAO::Tie::Array;

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

my role HashRole does PDF::DAO::Tie::Hash {
    has $.Foo is entry;
}

my role ArrayRole does PDF::DAO::Tie::Array {
    has $.Bar is index[1];
}

my role GenRole {
}

my $h1 = PDF::DAO.coerce: {};
lives-ok { PDF::DAO.coerce($h1, HashRole) }, 'tied hash role application';
does-ok $h1, HashRole, 'Hash/Hash application';
$h1.Foo = 42;
is $h1<Foo>, 42, 'tied hash';
is $h1.Foo, 42, 'tied hash accessor';

my $h2 = PDF::DAO.coerce: {};
warns-like { PDF::DAO.coerce($h2, ArrayRole) }, ::('X::PDF::Coerce'), 'Hash/Array misapplication';
ok !$h2.does(ArrayRole), 'Hash/Array misapplication';

my $a1 = PDF::DAO.coerce: [];
lives-ok { PDF::DAO.coerce($a1, ArrayRole) }, 'tied array role application';
does-ok $a1, ArrayRole, 'Hash/Hash application';
$a1.Bar = 69;
is $a1[1], 69, 'tied array accessor';
is $a1.Bar, 69, 'tied array accessor';

my $a2 = PDF::DAO.coerce: [];
warns-like { PDF::DAO.coerce($a2, HashRole) }, ::('X::PDF::Coerce'), 'Array/Hash misapplication';
ok !$a2.does(HashRole), 'Array/Hash misapplication';

my $h3 = PDF::DAO.coerce: {};
lives-ok { PDF::DAO.coerce($h3, GenRole) }, 'general hash role application';
does-ok $h3, GenRole, 'Hash/Gen application';

my $a3 = PDF::DAO.coerce: [];
lives-ok { PDF::DAO.coerce($a3, GenRole) }, 'general array role application';
does-ok $a3, GenRole, 'Array/Gen application';

done-testing;
