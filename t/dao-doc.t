use v6;
use Test;

use PDF::DAO;
use PDF::DAO::Doc;
use PDF::Grammar::PDF;

sub prefix:</>($name){ PDF::DAO.coerce(:$name) };

# ensure consistant document ID generation
srand(123456);

my $doc = PDF::DAO::Doc.new;
my $root     = $doc.Root       = { :Type(/'Catalog') };
my $outlines = $root<Outlines> = { :Type(/'Outlines'), :Count(0) };
my $pages    = $root<Pages>    = { :Type(/'Pages'), :Kids[], :Count(0) };

my $Contents = PDF::DAO.coerce( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) });
my @MediaBox = 0, 0, 420, 595;
my %Resources = :Procset[ /'PDF', /'Text'],
                :Font{
                  :F1{
                    :Type(/'Font'),
                    :Subtype(/'Type1'),
                    :BaseFont(/'Helvetica'),
        	    :Encoding(/'MacRomanEncoding'),
                  },
                };

$pages<Kids>.push: { :Type(/'Page'), :Parent($pages), :@MediaBox, :$Contents, :%Resources };
$pages<Count>++;

my $info = $doc.Info = {};
$info.CreationDate = DateTime.new( :year(2015), :month(12), :day(25) );
$info.Author = 'PDF-Tools/t/dao-doc.t';

lives-ok {$doc.save-as("t/helloworld.pdf")}, 'save-as pdf';
ok $doc.ID, 'doc ID generated';
my $doc-id = $doc.ID[0];
my $upd-id = $doc.ID[1];
is $upd-id, $doc-id, 'initial document ID';
lives-ok {$doc.save-as("t/pdf/samples/helloworld.json")}, 'save-as json';
is $doc.ID[0], $doc-id, 'document ID[0] - post update';
isnt $doc.ID[1], $doc-id, 'document ID[1] - post update';
ok PDF::Grammar::PDF.parse( $doc.Str ), '$doc.Str serialization';
done-testing;
