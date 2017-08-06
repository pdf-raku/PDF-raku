use v6;
use Test;
plan 33;

use PDF;
use PDF::Reader;
use PDF::Writer;
use PDF::DAO;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test :is-json-equiv;
use JSON::Fast;

sub name($name){ PDF::DAO.coerce(:$name) };

# ensure consistant document ID generation
srand(123456);

't/pdf/pdf.in'.IO.copy('t/pdf/pdf-updated.out');

my $pdf = PDF.open( 't/pdf/pdf-updated.out' );
my $reader = $pdf.reader;
is +$reader.xrefs, 1, 'reader.xrefs - initial';
my $catalog = $pdf<Root>;

{
    my $Parent = $catalog<Pages>;
    my $Resources = $Parent<Kids>[0]<Resources>;
    my $MediaBox = $Parent<Kids>[0]<MediaBox>;
    my $Contents = PDF::DAO.coerce( :stream{ :decoded("BT /F1 16 Tf  88 250 Td (and they all lived happily ever after!) Tj ET" ) } );
    $Parent<Kids>.push: { :Type(name 'Page'), :$MediaBox, :$Resources, :$Parent, :$Contents };
    $Parent<Count>++;
}

# firstly, write and analyse just the updates
lives-ok { $pdf.update(:prev(9999), :diffs("t/pdf/pdf.in-diffs".IO.open(:w)) ) }, 'update to PDF file - lives';
lives-ok { $pdf.update(:prev(9999), :diffs("t/pdf/pdf.in.json".IO.open(:w)) ) }, 'update to JSON file - lives';

my $actions = PDF::Grammar::PDF::Actions.new;
my Str $body-str = "t/pdf/pdf.in-diffs".IO.slurp( :enc<latin-1> );
ok PDF::Grammar::PDF.subparse( $body-str.trim, :rule<body>, :$actions), "can reparse update-body";
my $pdf-ast = $/.ast;
my $json-ast =  from-json("t/pdf/pdf.in.json".IO.slurp);

for $pdf-ast<body>, $json-ast<pdf><body>[0] -> $body {
    is-json-equiv $body<trailer><dict><Root>, (:ind-ref[1, 0]), 'body trailer dict - Root';
    is-json-equiv $body<trailer><dict><Size>, (:int(11)), 'body trailer dict - Size';
    is-json-equiv $body<trailer><dict><Prev>, (:int(9999)), 'body trailer dict - Prev';
    my $updated-objects = $body<objects>;
    is +$updated-objects, 3, 'number of updates';
    is-json-equiv $updated-objects[0], (
        :ind-obj[3, 0, :dict{ Kids => :array[ :ind-ref[4, 0], :ind-ref[9, 0]],
                              Count => :int(2),
                              Type => :name<Pages>,
                            }]), 'altered /Pages';

    is-json-equiv $updated-objects[1], (
        :ind-obj[9, 0, :dict{ MediaBox => :array[ :int(0), :int(0), :int(420), :int(595)],
                              Contents => :ind-ref[10, 0],
                              Resources => :dict{ Font => :dict{ F1 => :ind-ref[7, 0]},
                                                  ProcSet => :ind-ref[6, 0]},
                              Parent => :ind-ref[3, 0],
                              Type => :name<Page>,
                            }]), 'inserted page';

    is-json-equiv $updated-objects[2], (
        :ind-obj[10, 0, :stream{ :encoded("BT /F1 16 Tf  88 250 Td (and they all lived happily ever after!) Tj ET"),
                                 :dict{Length => :int(70) },
                               }]), 'inserted content';
}

my $ind-obj1 = $reader.ind-obj( 3, 0 );
my $ast1 = $ind-obj1.ast;
my $prev1 = $pdf.reader.prev;
my $size1 = $pdf.reader.size;
my $Info = $pdf.Info //= {};
$Info.ModDate = DateTime.new( :year(2015), :month(12), :day(26) );
$pdf.update;
is +$reader.xrefs, 2, 'reader.xrefs - post-update';
my $prev2 = $pdf.reader.prev;
ok $prev2 > $prev1, "reader.prev incremented by update"
   or diag "prev1:$prev1  prev2:$prev2";
my $size2 = $pdf.reader.size;
ok $size2 > $size1, "reader.size incremented by update"
   or diag "size1:$size1  size2:$size2";
my $ind-obj2;
lives-ok { $ind-obj2 = $reader.ind-obj( 3, 0 )}, "post update reader access - lives";

ok $ind-obj1 !=== $ind-obj2, 'indirect object has been updated';
my $ast2 = $ind-obj2.ast;
is-deeply $ast1<ind-obj>[2]<dict>.keys.sort, $ast2<ind-obj>[2]<dict>.keys.sort, 'indirect object dict';

is $pdf.Size, $size2, 'document trailer - updated Size';
isa-ok $pdf<Root><Pages><Kids>[1], PDF::DAO::Dict, 'updated page 2 access';

# now re-read the pdf. Will also test our ability to read a PDF
# with multiple body segments

my $pdf2 = PDF.open: 't/pdf/pdf-updated.out';
$reader = $pdf2.reader;
is $reader.type, 'PDF', 'reader type';
is +$reader.xrefs, 2, 'reader.xrefs - reread';

my $ast = $reader.ast( :rebuild );
is $ast<pdf><header><type>, 'PDF', 'pdf ast type';
is +$ast<pdf><body>, 1, 'single body';
is +$ast<pdf><body>[0]<objects>, 10, 'read-back has object count';
is-deeply $ast<pdf><body>[0]<objects>[9], ( :ind-obj[10, 0, :stream{ :dict{ Length => :int(70)},
                                                                     :encoded("BT /F1 16 Tf  88 250 Td (and they all lived happily ever after!) Tj ET")},
                              ]), 'inserted content';

# do a full rewrite of the updated PDF. Output should be cleaned up, with a single body and
# cleansed of old object versions.
ok $pdf2.save-as('t/pdf/pdf-updated-and-rebuilt.pdf', :rebuild), 'save-as :rebuild';

done-testing;
