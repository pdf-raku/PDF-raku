use v6;
use Test;

use PDF::DAO;
use PDF::DAO::Doc;

sub prefix:</>($name){ PDF::DAO.coerce(:$name) };

my $doc = PDF::DAO::Doc.new;
my $root     = $doc.Root       = { :Type(/'Catalog') };
my $outlines = $root<Outlines> = { :Type(/'Outlines'), :Count(0) };
my $pages    = $root<Pages>    = { :Type(/'Pages') };

$pages<Kids> = [ { :Type(/'Page'), :MediaBox[0, 0, 420, 595] }, ];
$pages<Count> = + $pages<Kids>;
my $page = $pages<Kids>[0];
$page<Parent> = $pages;

$page<Resources><Procset> = [ /'PDF', /'Text'];
$page<Resources><Font><F1> = {
        :Type(/'Font'),
        :Subtype(/'Type1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    };

$page<Contents> = PDF::DAO.coerce( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) } );

my $info = $doc.Info = {};
$info.CreationDate = DateTime.new( :year(2015), :month(12), :day(25) );
$info.Author = 'PDF-Tools/t/helloworld.t';

lives-ok {$doc.save-as("t/helloworld.pdf")}, 'save-as pdf';
lives-ok {$doc.save-as("t/pdf/samples/helloworld.json")}, 'save-as json';
done-testing;
