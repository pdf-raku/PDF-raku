use v6;
use Test;

# hypothetical - todo of 25-Feb-15:
# (a) a number of new Type classess: Outlines, Pages, Page, Font::Type1
# (b) better handling of references: $page.Contents = $contents
# (c) make PDF::Writer smarter, should:
#     i.    only need the root object to fully serialize,
#     ii.   be able to automatically generate object numbers, and
#     iii.  accept :output file handle option

use PDF::Tools::IndObj::Stream;
use PDF::Tools::IndObj::Dict;
use PDF::Tools::IndObj::Type::Catalog;
use PDF::Tools::IndObj::Type::Outlines;
use PDF::Tools::IndObj::Type::Pages;
use PDF::Tools::IndObj::Type::Page;
use PDF::Tools::IndObj::Type::Font::Type1;
use PDF::Writer;

sub prefix:</>($n){:name($n)};

my $root-object = PDF::Tools::IndObj::Type::Catalog.new;
my $outlines = PDF::Tools::IndObj::Type::Outlines.new;
$root-object.Outlines( $outlines );

my $pages = PDF::Tools::IndObj::Type::Pages.new;
$root-object.Pages( $pages );

my $Procset = PDF::Tools::IndObj::Dict.new( :dict{ :array[ /'PDF', /'Text' ] } );
my $page = PDF::Tools::IndObj::Type::Page.new;
$pages.Page( $page );

my $font = PDF::Tools::IndObj::Type::Font::Type1.new(
    :dict{
        :Name(/'F1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    });

$pages.Resource<Font> = :dict{ :Font{ :F1($font) }, :$Procset };

my $contents = PDF::Tools::IndObj::Stream.new( :decoded("100 250 Td (Hello, world!) Tj" );
$page.Contents = $contents;

my $writer = PDF::Writer.new( :$root-object );
my $helloworld-ioh = '/tmp/helloworld.pdf'.IO.open( :w, :enc<latin-1> );
ok $writer.write( :output($helloworld-ioh)), 'hello world';
done;
