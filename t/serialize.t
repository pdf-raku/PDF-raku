use v6;
use Test;

use PDF::Tools::Serializer;
use PDF::Object :box;

sub prefix:</>($name){
    use PDF::Object;
    PDF::Object.compose(:$name)
};

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
                                 :Procset[<PDF Text>],
                     },
                     :Contents( PDF::Object.compose( :stream{ :encoded("/F1 24 Tf  100 250 Td (Hello, world!) Tj") } ) ),
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

is +$objects, 6, 'number of objects';
is_deeply $objects[*-1], (:ind-obj[6, 0, :dict{Pages => :ind-ref[4, 0], Outlines => :ind-ref[5, 0], :Type{:name<Catalog>}}]), 'root object';

done;
