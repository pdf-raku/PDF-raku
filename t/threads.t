use v6;
use Test;
plan 1;

use PDF;
use PDF::COS::Dict;
use PDF::COS::Name;
use PDF::COS::Stream;
use PDF::Grammar::PDF;

constant PAGES = 120;

sub name($name){ PDF::COS::Name.COERCE($name) };

# ensure consistent document ID generation
my $id = $*PROGRAM-NAME.fmt('%-16.16s');

my PDF:D $pdf .= new;
my $root      = $pdf.Root       = { :Type(name 'Catalog') };
my $outlines  = $root<Outlines> = { :Type(name 'Outlines'), :Count(0) };

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

my PDF::COS::Dict:D $page-tree-root = $root<Pages>    = { :Type(name 'Pages'), :Kids[], :Count(0), :@MediaBox, :%Resources };
my @pages = (^PAGES).hyper(:batch(1)).map: {
    my PDF::COS::Stream() $Contents = { :decoded("BT /F1 24 Tf  100 450 Td (Hello, page {$_+1}!) Tj ET" ) };

    { :Type(name 'Page'), :Parent($page-tree-root), :@MediaBox, :$Contents };
}

$page-tree-root<Kids> = @pages;
$page-tree-root<Count> = +@pages;

my $info = $pdf.Info = {};
$info.CreationDate = DateTime.new( :year(2015), :month(12), :day(25) );
$info.Author = 'PDF-Tools/t/threads.t';
$pdf.save-as: "tmp/threads.pdf";

# now lets see, if we can concurrently update pages
$pdf .= open: "tmp/threads.pdf";

$page-tree-root = $pdf.Root<Pages>;

(^PAGES).race.map: -> $idx {
    my $n = $idx + 1;
    my PDF::COS::Dict:D $page = $page-tree-root<Kids>[$idx];

    my PDF::COS::Stream:D $contents = $page<Contents>;
    $contents.decoded ~= " BT /F1 24 Tf  100 400 Td ($n) Tj ET";
}

lives-ok { $pdf.update }

done-testing;
