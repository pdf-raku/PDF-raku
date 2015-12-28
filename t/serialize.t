use v6;
use Test;

use PDF::Storage::Serializer;
use PDF::DAO::Util :to-ast;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Writer;

sub prefix:</>($name){
    use PDF::DAO;
    PDF::DAO.coerce(:$name)
};

# construct a nasty cyclic structure
my $dict1 = { :ID(1) };
my $dict2 = { :ID(2) };
# create circular hash ref
$dict2<SelfRef> := $dict2;

my $doc = PDF::DAO.coerce: { :Root[ $dict1, $dict2 ] };
# create circular array reference
$doc<Root>[2] := $doc<Root>;

# cycle back from hash to array
$doc<Root>[0]<Parent> := $doc<Root>;

my $doc-ast = to-ast($doc);
is $doc-ast<dict><Root><array>[1]<dict><ID><int>, 2, 'ast dereference';

# our serializer should create indirect refs to resolve the above
my $body = PDF::Storage::Serializer.new.body( $doc )[0];
is-deeply $body<trailer><dict><Root>, (:ind-ref[1, 0]), 'body trailer dict - Root';
is-deeply $body<trailer><dict><Size>, (:int(3)), 'body trailer dict - Size';
my $s-objects = $body<objects>;
is +$s-objects, 2, 'expected number of objects';
is-deeply $s-objects[0], (:ind-obj[1, 0, :array[ :dict{ID => :int(1), Parent => :ind-ref[1, 0]},
                                                 :ind-ref[2, 0],
                                                 :ind-ref[1, 0]]]), "circular array reference resolution";

is-deeply $s-objects[1], (:ind-obj[2, 0, :dict{SelfRef => :ind-ref[2, 0], ID => :int(2)}]), "circular hash ref resolution";

$doc = PDF::DAO.coerce: { :Root{
    :Type(/'Catalog'),
    :Pages{
            :Type(/'Pages'),
            :Kids[ { :Type(/'Page'),
                     :Resources{ :Font{ :F1{ :Encoding(/'MacRomanEncoding'),
                                             :BaseFont(/'Helvetica'),
                                             :Name(/'F1'),
                                             :Type(/'Font'),
                                             :Subtype(/'Type1')},
                                 },
                                 :Procset[ /'PDF',  /'Text' ],
                     },
                     :Contents( PDF::DAO.coerce( :stream{ :encoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET") } ) ),
                   },
                ],
            :Count(1),
    },
    :Outlines{ :Type(/'Outlines'), :Count(0) },
} };

$doc<Root><Pages><Kids>[0]<Parent> = $doc<Root><Pages>;

$body = PDF::Storage::Serializer.new.body( $doc )[0];
my $objects = $body<objects>;

sub infix:<object-order-ok>($obj-a, $obj-b) {
    my ($obj-num-a, $gen-num-a) = @( $obj-a.value );
    my ($obj-num-b, $gen-num-b) = @( $obj-b.value );
    my $ok = $obj-num-a < $obj-num-b
        || ($obj-num-a == $obj-num-b && $gen-num-a < $gen-num-b);
    die  "objects out of sequence: $obj-num-a $gen-num-a R is not <= $obj-num-a $gen-num-b R"
         unless $ok;
    $obj-b
}

ok ([object-order-ok] @$objects), 'objects are in order';
is +$objects, 6, 'number of objects';
is-json-equiv $objects[0], (:ind-obj[1, 0, :dict{
                                               Type => { :name<Catalog> },
                                               Pages => :ind-ref[3, 0],
                                               Outlines => :ind-ref[2, 0],
                                             },
                                   ]), 'root object';

is-json-equiv $objects[3], (:ind-obj[4, 0, :dict{
                                              Resources => :dict{Procset => :array[ :name<PDF>, :name<Text>],
                                              Font => :dict{F1 => :ind-ref[6, 0]}},
                                              Type => :name<Page>,
                                              Contents => :ind-ref[5, 0],
                                              Parent => :ind-ref[3, 0],
                                               },
                                   ]), 'page object';

my $obj-with-utf8 = PDF::DAO.coerce: { :Root{ :Name(/"Heydər Əliyev") } };
$obj-with-utf8<Root>.obj-num = -1;
my $writer = PDF::Writer.new;

$objects = PDF::Storage::Serializer.new.body($obj-with-utf8)[0]<objects>;
is-json-equiv $objects, [:ind-obj[1, 0, :dict{ Name => :name("Heydər Əliyev")}]], 'name serialization';
is $writer.write( :ind-obj($objects[0].value)), "1 0 obj <<\n  /Name /Heyd#c9#99r#20#c6#8fliyev\n>> endobj", 'name write';

my $objects-compressed = PDF::Storage::Serializer.new.body($doc, :compress)[0]<objects>;
my $stream = $objects-compressed[*-2].value[2]<stream>;
is-deeply $stream<dict>, { :Filter(:name<FlateDecode>), :Length(:int(54))}, 'compressed dict';
is $stream<encoded>.codes, 54, 'compressed stream length';

# just to define current behaviour. blows up during final write.
my $obj-with-bad-byte-string = PDF::DAO.coerce: { :Root{ :Name("Heydər Əliyev") } };
$objects = PDF::Storage::Serializer.new.body($obj-with-bad-byte-string)<objects>;
dies-ok {$writer.write( :ind-obj($objects[0].value) )}, 'out-of-range byte-string dies during write';

done-testing;
