use v6;
use Test;

use PDF::Object;
use PDF::Object::Doc;

sub prefix:</>($name){ PDF::Object.coerce(:$name) };
my $Root = PDF::Object.coerce: { :Type(/'Catalog') };
my $outlines = PDF::Object.coerce: { :Type(/'Outlines'), :Count(0) };
$Root<Outlines> = $outlines;

my $pages = PDF::Object.coerce: { :Type(/'Pages') };
$Root<Pages> = $pages;

my $page = PDF::Object.coerce: { :Type(/'Page'), :MediaBox[0, 0, 420, 595] };
$pages<Kids> = [ $page ];
$pages<Count> = + $pages<Kids>;

my $font = PDF::Object.coerce: {
        :Type(/'Font'),
        :Subtype(/'Type1'),
        :Name(/'F1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    };

$page<Resources> = { :Font{ :F1($font) }, :Procset[ /'PDF', /'Text'] };

my $contents = PDF::Object.coerce( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) } );
$page<Contents> = $contents;
$page<Parent> = $pages;

my $Info = PDF::Object.coerce( { :CreationDate( DateTime.new( :year(1999) ) ), :Author<PDF-Tools/t/helloworld.t> } );

my $doc = PDF::Object::Doc.new( { :$Root :$Info } );
lives-ok {$doc.save-as("t/helloworld.pdf")};
done-testing;
