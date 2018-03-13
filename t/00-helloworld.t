use v6;
use Test;
plan 7;

use PDF;
use PDF::COS;
use PDF::Grammar::PDF;

sub name($name){ PDF::COS.coerce(:$name) };

# ensure consistant document ID generation
srand(123456);

my $pdf = PDF.new;
my $root     = $pdf.Root       = { :Type(name 'Catalog') };
my $outlines = $root<Outlines> = { :Type(name 'Outlines'), :Count(0) };
my $pages    = $root<Pages>    = { :Type(name 'Pages'), :Kids[], :Count(0) };

my $Contents = PDF::COS.coerce( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) });
my @MediaBox = 0, 0, 420, 595;
my %Resources = :Procset[ name('PDF'), name('Text')],
                :Font{
                  :F1{
                    :Type(name 'Font'),
                    :Subtype(name 'Type1'),
                    :BaseFont(name 'Helvetica'),
        	    :Encoding(name 'MacRomanEncoding'),
                  },
                };

$pages<Kids>.push: { :Type(name 'Page'), :Parent($pages), :@MediaBox, :$Contents, :%Resources };
$pages<Count>++;

my $info = $pdf.Info = {};
$info.CreationDate = DateTime.new( :year(2015), :month(12), :day(25) );
$info.Author = 'PDF-Tools/t/cos-doc.t';

lives-ok {$pdf.save-as("t/helloworld.pdf")}, 'save-as pdf';
ok $pdf.ID, 'doc ID generated';
my $pdf-id = $pdf.ID[0];
my $upd-id = $pdf.ID[1];
is $upd-id, $pdf-id, 'initial document ID';
lives-ok {$pdf.save-as("t/pdf/samples/helloworld.json")}, 'save-as json';
is $pdf.ID[0], $pdf-id, 'document ID[0] - post update';
isnt $pdf.ID[1], $pdf-id, 'document ID[1] - post update';
ok PDF::Grammar::PDF.parse( $pdf.Str ), '$pdf.Str serialization';
done-testing;
