use v6;
use Test;

use PDF::Object;
use PDF::Writer;

sub prefix:</>($name){
    PDF::Object.compose(:$name)
};

my $root-object = PDF::Object.compose( :dict{ :Type(/'Catalog') });
my $outlines = PDF::Object.compose( :dict{ :Type(/'Outlines'), :Count(0) } );
$root-object.Outlines = $outlines;

my $pages = PDF::Object.compose( :dict{ :Type(/'Pages') } );
$root-object.Pages = $pages;

my $Procset = PDF::Object.compose( :array[ /'PDF', /'Text' ] );
my $page = PDF::Object.compose( :dict{ :Type(/'Page') } );
$pages.Kids = [ $page ];
$pages.Count = 1;

my $font = PDF::Object.compose(
    :dict{
        :Type(/'Font'),
        :Subtype(/'Type1'),
        :Name(/'F1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    });

$page.Resources = { :Font{ :F1($font) }, :$Procset };

my $contents = PDF::Object.compose( :stream{ :decoded("/F1 24 Tf  100 250 Td (Hello, world!) Tj" ) } );
$page.Contents = $contents;

my $result = $root-object.serialize;
my $root = $result<root>;
my $objects = $result<objects>;

my $ast = :pdf{ :version(1.2), :body{ :$objects } };

my $writer = PDF::Writer.new( :$root );
my $helloworld-iop = 't/helloworld.pdf'.IO;
ok $helloworld-iop.spurt( $writer.write( $ast ), :enc<latin-1> ), 'hello world';
done;
