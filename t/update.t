use v6;
use Test;
plan 37;

use PDF;
use PDF::IO::Reader;
use PDF::IO::Writer;
use PDF::COS;
use PDF::COS::Name;
use PDF::COS::Stream;
use PDF::COS::Type::XRef;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test :is-json-equiv;
use JSON::Fast;

sub name($name){ PDF::COS::Name.COERCE($name) };

# ensure consistant document ID generation
my $id = $*PROGRAM-NAME.fmt('%-16.16s');

my PDF $pdf .= open( 't/pdf/pdf.in' );

my $reader = $pdf.reader;
is +$reader.xrefs, 1, 'reader.xrefs - initial';
my $catalog = $pdf<Root>;

{
    my $Parent = $catalog<Pages>;
    my $Resources = $Parent<Kids>[0]<Resources>;
    my $MediaBox = $Parent<Kids>[0]<MediaBox>;
    my PDF::COS::Stream() $Contents = { :decoded("BT /F1 16 Tf  88 250 Td (and they all lived happily ever after!) Tj ET" ) };
    $Parent<Kids>.push: { :Type(name 'Page'), :$MediaBox, :$Resources, :$Parent, :$Contents };
    $Parent<Count>++;
}

# firstly, write and analyse just the updates
$pdf.id = $id++;
lives-ok {$pdf.update(:prev(9999), :diffs("t/pdf/pdf.in-diffs".IO.open(:w)) ); }, 'update to PDF file - lives';
$pdf.id = $id++;
lives-ok { $pdf.update(:prev(9999), :diffs("tmp/pdf.in.json".IO.open(:w)) ) }, 'update to JSON file - lives';

my PDF::Grammar::PDF::Actions $actions .= new: :lite;
my Str $body-str = "t/pdf/pdf.in-diffs".IO.slurp(:bin).decode('latin-1');
ok PDF::Grammar::PDF.subparse( $body-str.trim, :rule<body>, :$actions), "can reparse update-body";
my $pdf-ast = $/.ast;
my $json-ast =  from-json("tmp/pdf.in.json".IO.slurp);

for $pdf-ast<body>, $json-ast<cos><body>[0] -> $body {
    is-json-equiv $body<trailer><dict><Root>, (:ind-ref[1, 0]), 'body trailer dict - Root';
    is-json-equiv $body<trailer><dict><Size>, 11, 'body trailer dict - Size';
    is-json-equiv $body<trailer><dict><Prev>, 9999, 'body trailer dict - Prev';
    my $updated-objects = $body<objects>;
    is +$updated-objects, 3, 'number of updates';
    is-json-equiv $updated-objects[0], (
        :ind-obj[3, 0, :dict{ Kids => :array[ :ind-ref[4, 0], :ind-ref[9, 0]],
                              :Count(2),
                              Type => :name<Pages>,
                            }]), 'altered /Pages';

    is-json-equiv $updated-objects[1], (
        :ind-obj[9, 0, :dict{ MediaBox => :array[ 0, 0, 420, 595],
                              Contents => :ind-ref[10, 0],
                              Resources => :dict{ Font => :dict{ F1 => :ind-ref[7, 0]},
                                                  ProcSet => :ind-ref[6, 0]},
                              Parent => :ind-ref[3, 0],
                              Type => :name<Page>,
                            }]), 'inserted page';

    is-json-equiv $updated-objects[2], (
        :ind-obj[10, 0, :stream{ :encoded("BT /F1 16 Tf  88 250 Td (and they all lived happily ever after!) Tj ET"),
                                 :dict{ :Length(70) },
                               }]), 'inserted content';
}

my $ind-obj1 = $reader.ind-obj( 3, 0 );
my $ast1 = $ind-obj1.ast;
my $prev1 = $pdf.reader.prev;
my $size1 = $pdf.reader.size;
my $Info = $pdf.Info //= {};
$Info.ModDate = DateTime.new( :year(2015), :month(12), :day(26) );

# save-as - does an increment save by default
$pdf.id = $id++;
$pdf.save-as('t/pdf/pdf-updated.out');
$pdf .= open('t/pdf/pdf-updated.out');
$reader = $pdf.reader;

# See that we've updated the in-memory PDF

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

is $reader.size, $size2, 'document trailer - updated Size';
isa-ok $pdf<Root><Pages><Kids>[1], PDF::COS::Dict, 'updated page 2 access';

# now re-read the pdf. Will also test our ability to read a PDF
# with multiple body segments

my PDF $pdf2 .= open: 't/pdf/pdf-updated.out';
$reader = $pdf2.reader;
is $reader.type, 'PDF', 'reader type';
is +$reader.xrefs, 2, 'reader.xrefs - reread';
is $reader.compat, v1.2, 'reader compat';

my $ast = $reader.ast( :rebuild );
is $ast<cos><header><type>, 'PDF', 'pdf ast type';
is +$ast<cos><body>, 1, 'single body';
is +$ast<cos><body>[0]<objects>, 10, 'read-back has object count';
is-json-equiv $ast<cos><body>[0]<objects>[9], ( :ind-obj[10, 0, :stream{ :dict{ :Length(70)},
                                                                     :encoded("BT /F1 16 Tf  88 250 Td (and they all lived happily ever after!) Tj ET")},
                              ]), 'inserted content';

# do a full rewrite of the updated PDF. Output should be cleaned up, with a single body and
# cleansed of old object versions.
$pdf2.id = $id++;
ok $pdf2.save-as('t/pdf/pdf-updated-and-rebuilt.pdf', :rebuild), 'save-as :rebuild';

$pdf .= open( 't/pdf/pdf-updated-and-rebuilt.pdf' );
$reader = $pdf.reader;
is +$reader.xrefs, 1, 'reader.xrefs - rebuilt';

# issue #22: if a PDF with cross reference streams is updated, we should also
# write the updates as a cross reference stream

$pdf .= open: "t/pdf/samples/pdf-1.5-obstm_and_xref_streams.pdf";
$pdf.Info.Subject = 'test update of PDF with XRef streams';
$pdf.id = $id++;
$pdf.save-as: "tmp/pdf-1.5-updated.pdf";
lives-ok {$pdf .= open: "tmp/pdf-1.5-updated.pdf"}, "read of updated 1.5+ PDF lives";
is $pdf.reader.compat, v1.5, 'reader compat';

done-testing;
