use v6;
use Test;

use PDF::DAO;
use PDF::DAO::Doc;

sub prefix:</>($name){ PDF::DAO.coerce(:$name) };
my $Root = PDF::DAO.coerce: { :Type(/'Catalog') };
my $outlines = PDF::DAO.coerce: { :Type(/'Outlines'), :Count(0) };
$Root<Outlines> = $outlines;

my $pages = PDF::DAO.coerce: { :Type(/'Pages') };
$Root<Pages> = $pages;

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

my $Info = PDF::DAO.coerce( { :CreationDate( DateTime.new( :year(1999) ) ), :Author<PDF-Tools/t/helloworld.t> } );

my $doc = PDF::DAO::Doc.new( { :$Root, :$Info } );
lives-ok {$doc.save-as("t/helloworld.pdf")};
done-testing;
