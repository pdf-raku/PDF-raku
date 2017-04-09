use v6;
use Test;
plan 17;

use PDF::IO::Serializer;
use PDF::DAO::Util :to-ast;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Writer;
use PDF::DAO;

sub name($name){ PDF::DAO.coerce(:$name) };

# construct a nasty cyclic structure
my $dict1 = { :ID(1) };
my $dict2 = { :ID(2) };
# create circular hash ref
$dict2<SelfRef> := $dict2;

my $pdf = PDF::DAO.coerce: { :Root[ $dict1, $dict2 ] };
# create circular array reference
$pdf<Root>[2] := $pdf<Root>;

# cycle back from hash to array
$pdf<Root>[0]<Parent> := $pdf<Root>;

my $pdf-ast = to-ast($pdf);
is $pdf-ast<dict><Root><array>[1]<dict><ID><int>, 2, 'ast dereference';

# our serializer should create indirect refs to resolve the above
my $body = PDF::IO::Serializer.new.body( $pdf )[0];
is-deeply $body<trailer><dict><Root>, (:ind-ref[1, 0]), 'body trailer dict - Root';
is-deeply $body<trailer><dict><Size>, (:int(3)), 'body trailer dict - Size';
my $s-objects = $body<objects>;
is +$s-objects, 2, 'expected number of objects';
is-deeply $s-objects[0], (:ind-obj[1, 0, :array[ :dict{ID => :int(1), Parent => :ind-ref[1, 0]},
                                                 :ind-ref[2, 0],
                                                 :ind-ref[1, 0]]]), "circular array reference resolution";

is-deeply $s-objects[1], (:ind-obj[2, 0, :dict{SelfRef => :ind-ref[2, 0], ID => :int(2)}]), "circular hash ref resolution";

$pdf = PDF::DAO.coerce: { :Root{
    :Type(name 'Catalog'),
    :Pages{
            :Type(name 'Pages'),
            :Kids[ { :Type(name 'Page'),
                     :Resources{ :Font{ :F1{ :Encoding(name 'MacRomanEncoding'),
                                             :BaseFont(name 'Helvetica'),
                                             :Name(name 'F1'),
                                             :Type(name 'Font'),
                                             :Subtype(name 'Type1')},
                                 },
                                 :Procset[ name('PDF'),  name('Text') ],
                     },
                     :Contents( PDF::DAO.coerce( :stream{ :encoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET") } ) ),
                   },
                ],
            :Count(1),
    },
    :Outlines{ :Type(name 'Outlines'), :Count(0) },
} };

$pdf<Root><Pages><Kids>[0]<Parent> = $pdf<Root><Pages>;

$body = PDF::IO::Serializer.new.body( $pdf )[0];
my @objects = @($body<objects>);

sub obj-sort {
    my ($obj-num-a, $gen-num-a) = @( $^a.value );
    my ($obj-num-b, $gen-num-b) = @( $^b.value );
    $obj-num-a <=> $obj-num-b || $gen-num-a <=> $gen-num-b
}

is-deeply [@objects.sort(&obj-sort)], @objects, 'objects are in order';
is +@objects, 6, 'number of objects';
is-json-equiv @objects[0], (:ind-obj[1, 0, :dict{
                                               Type => { :name<Catalog> },
                                               Pages => :ind-ref[3, 0],
                                               Outlines => :ind-ref[2, 0],
                                             },
                                   ]), 'root object';

is-json-equiv @objects[3], (:ind-obj[4, 0, :dict{
                                              Resources => :dict{Procset => :array[ :name<PDF>, :name<Text>],
                                              Font => :dict{F1 => :ind-ref[6, 0]}},
                                              Type => :name<Page>,
                                              Contents => :ind-ref[5, 0],
                                              Parent => :ind-ref[3, 0],
                                               },
                                   ]), 'page object';

my $obj-with-utf8 = PDF::DAO.coerce: { :Root{ :Name(name "Heydər Əliyev") } };
$obj-with-utf8<Root>.is-indirect = True;
my $writer = PDF::Writer.new;

@objects = @(PDF::IO::Serializer.new.body($obj-with-utf8)[0]<objects>);
is-json-equiv @objects, [:ind-obj[1, 0, :dict{ Name => :name("Heydər Əliyev")}]], 'name serialization';
is $writer.write( :ind-obj(@objects[0].value)), "1 0 obj <<\n  /Name /Heyd#c9#99r#20#c6#8fliyev\n>>\nendobj\n", 'name write';

my @objects-renumbered = @(PDF::IO::Serializer.new.body($obj-with-utf8, :size(1000))[0]<objects>);
is-json-equiv @objects-renumbered, [:ind-obj[1000, 0, :dict{ Name => :name("Heydər Əliyev")}]], 'renumbered serialization';
is $writer.write( :ind-obj(@objects-renumbered[0].value)), "1000 0 obj <<\n  /Name /Heyd#c9#99r#20#c6#8fliyev\n>>\nendobj\n", 'renumbered write';

my @objects-compressed = @(PDF::IO::Serializer.new.body($pdf, :compress)[0]<objects>);
my $stream = @objects-compressed[*-2].value[2]<stream>;
is-deeply $stream<dict>, { :Filter(:name<FlateDecode>), :Length(:int(54))}, 'compressed dict';
is $stream<encoded>.codes, 54, 'compressed stream length';

# just to define current behaviour wrt to non-latin chars; blows up during write.
my $obj-with-bad-byte-string = PDF::DAO.coerce: { :Root{ :Name("Heydər Əliyev") } };
@objects = @(PDF::IO::Serializer.new.body($obj-with-bad-byte-string)<objects>);
dies-ok {$writer.write( :ind-obj(@objects[0].value) )}, 'out-of-range byte-string dies during write';

done-testing;
