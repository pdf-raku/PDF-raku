use v6;
use Test;

use PDF::Object::Stream;
use PDF::Object::Dict;
use PDF::Object::Array;
use PDF::Object::Type::Catalog;
use PDF::Object::Type::Outlines;
use PDF::Object::Type::Pages;
use PDF::Object::Type::Page;
use PDF::Object::Type::Font::Type1;
use PDF::Writer;

sub prefix:</>($name){
    PDF::Object.compose(:$name)
};

my $root-object = PDF::Object::Type::Catalog.new;
my $outlines = PDF::Object::Type::Outlines.new( :dict{ :Count(0) } );
$root-object.Outlines = $outlines;

my $pages = PDF::Object::Type::Pages.new;
$root-object.Pages = $pages;

my $Procset = PDF::Object::Array.new( :array[ /'PDF', /'Text' ] );
my $page = PDF::Object::Type::Page.new;
$pages.Kids = [ $page ];
$pages.Count = 1;

my $font = PDF::Object::Type::Font::Type1.new(
    :dict{
        :Name(/'F1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    });

$page.Resources = { :Font{ :F1($font) }, :$Procset };

my $contents = PDF::Object::Stream.new( :decoded("/F1 24 Tf  100 250 Td (Hello, world!) Tj" ) );
$page.Contents = $contents;

my $result = $root-object.serialize;
my $root = $result<root>;
my $objects = $result<objects>;

my $ast = :pdf{ :version(1.2), :body{ :$objects } };

my $writer = PDF::Writer.new( :$root );
my $helloworld-iop = 't/helloworld.pdf'.IO;
ok $helloworld-iop.spurt( $writer.write( $ast ), :enc<latin-1> ), 'hello world';
done;
