use v6;
use Test;
plan 11;

use PDF;
use PDF::COS::Name;
use PDF::COS::Stream;
use PDF::Grammar::PDF;

sub name($name){ PDF::COS::Name.COERCE($name) };

# ensure consistant document ID generation
my $id = $*PROGRAM-NAME.fmt('%-16.16s');

my PDF $pdf .= new;
my $root     = $pdf.Root       = { :Type(name 'Catalog') };
my $outlines = $root<Outlines> = { :Type(name 'Outlines'), :Count(0) };
my $pages    = $root<Pages>    = { :Type(name 'Pages'), :Kids[], :Count(0) };

my PDF::COS::Stream() $Contents = { :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) };
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
$info.Author = 'PDF-Tools/t/00-helloworld.t';

$pdf.id = $id++;
lives-ok {$pdf.save-as("t/helloworld.pdf")}, 'save-as pdf';
ok $pdf.ID, 'doc ID generated';
my $pdf-id = $pdf.ID[0];
my $upd-id = $pdf.ID[1];
is $upd-id, $pdf-id, 'initial document ID';
lives-ok {$pdf.save-as("tmp/helloworld.json")}, 'save-as json';
is $pdf.ID[0], $pdf-id, 'document ID[0] - post update';
isnt $pdf.ID[1], $pdf-id, 'document ID[1] - post update';
ok PDF::Grammar::PDF.parse( $pdf.Str ), '$pdf.Str serialization';
ok PDF::Grammar::PDF.parse( $pdf.Str: :compat(v1.5) ), '$pdf.Str v1.5 serialization';
lives-ok {$pdf .= open: $pdf.Blob}, 'reserialize from Blob';
is-deeply $pdf.Info.Author, $info.Author, 'Info intact';
lives-ok {$pdf.Blob}, 'second reserialization';
done-testing;
