use v6;
use Test;

use PDF::Object;
use PDF::Storage::Serializer;
use PDF::Writer;

sub prefix:</>($name){ PDF::Object.compose(:$name) };

my $root-object = PDF::Object.compose( :dict{ :Type(/'Catalog') });
my $outlines = PDF::Object.compose( :dict{ :Type(/'Outlines'), :Count(0) } );
$root-object.Outlines = $outlines;

my $pages = PDF::Object.compose( :dict{ :Type(/'Pages') } );
$root-object.Pages = $pages;

my $page = PDF::Object.compose( :dict{ :Type(/'Page'), :MediaBox[0, 0, 420, 595] } );
$pages.Kids = [ $page ];
$pages.Count = + $pages.Kids;

my $font = PDF::Object.compose(
    :dict{
        :Type(/'Font'),
        :Subtype(/'Type1'),
        :Name(/'F1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    });

$page.Resources = { :Font{ :F1($font) }, :Procset[ /'PDF', /'Text'] };

my $contents = PDF::Object.compose( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) } );
$page.Contents = $contents;

my $result = PDF::Storage::Serializer.new.serialize-doc($root-object);
my $root = $result<root>;
my $objects = $result<objects>;

my $ast = :pdf{ :version(1.2), :body{ :$objects } };

my $writer = PDF::Writer.new( :$root );
ok 't/helloworld.pdf'.IO.spurt( $writer.write( $ast ), :enc<latin-1> ), 'hello world';
done;
