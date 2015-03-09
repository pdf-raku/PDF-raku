use v6;
use Test;

use PDF::Tools::Serializer;
use PDF::Object :box;
use PDF::Grammar::Test :is-json-equiv;

sub prefix:</>($name){
    use PDF::Object;
    PDF::Object.compose(:$name)
};

my $dict1 = PDF::Object.compose( :dict{ :ID(1) } );
my $dict2 = PDF::Object.compose( :dict{ :ID(2) } );
my $array = PDF::Object.compose( :array[ $dict1, $dict2, $dict1 ]);

my $result = $array.serialize;
my $object = $result<objects>;
todo "issue#1 this should serialize to 3 objects (1 array and 2 dicts)";
is +$object, 3, 'expected number of objects';

my %body = (
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
                     :Contents( PDF::Object.compose( :stream{ :encoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET") } ) ),
                   }
                ],
            :Count(1),
    },
    :Outlines{ :Type(/'Outlines'), :Count(0) },
    );

my $dict = (box %body).value;
my $serializer = PDF::Tools::Serializer.new;
my $root = $serializer.freeze( :$dict );
my $objects = $serializer.ind-objs;

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
is-json-equiv $objects[5], (:ind-obj[6, 0, :dict{
                                               Type => { :name<Catalog> },
                                               Pages => :ind-ref[4, 0],
                                               Outlines => :ind-ref[5, 0],
                                             },
                                   ]), 'root object';
todo "issue#2 generate Parent indirect references";
is-json-equiv $objects[2], (:ind-obj[3, 0, :dict{
                                              Resources => :dict{Procset => :array[ :name<PDF>, :name<Text>],
                                              Font => :dict{F1 => :ind-ref[1, 0]}},
                                              Type => :name<Page>,
                                              Contents => :ind-ref[2, 0],
                                              Parent => :ind-ref[4, 0],
                                               },
                                   ]), 'page object';

done;
