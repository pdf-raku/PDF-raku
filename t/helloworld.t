use v6;
use Test;

use PDF::DAO;
use PDF::DAO::Doc;

sub prefix:</>($name){ PDF::DAO.coerce(:$name) };
my $doc = PDF::DAO::Doc.new;
my $Root     = $doc.Root       = { :Type(/'Catalog') };
my $outlines = $Root<Outlines> = { :Type(/'Outlines'), :Count(0) };
my $pages    = $Root<Pages>    = { :Type(/'Pages') };

my $page = PDF::DAO.coerce: { :Type(/'Page'), :MediaBox[0, 0, 420, 595] };
$pages<Kids> = [ $page ];
$pages<Count> = + $pages<Kids>;

my $font = PDF::DAO.coerce: {
        :Type(/'Font'),
        :Subtype(/'Type1'),
        :Name(/'F1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    };

$page<Resources> = { :Font{ :F1($font) }, :Procset[ /'PDF', /'Text'] };

my $contents = PDF::DAO.coerce( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) } );
$page<Contents> = $contents;
$page<Parent> = $pages;

my $Info = $doc.Info = {};
$Info.CreationDate = DateTime.new( :year(1999) );
$Info.Author = 'PDF-Tools/t/helloworld.t';

lives-ok {$doc.save-as("t/helloworld.pdf")};
done-testing;
