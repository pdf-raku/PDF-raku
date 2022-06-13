use v6;
use Test;
plan 5;

use PDF;
use PDF::COS::Stream;

# ensure consistant document ID generation
my $id = $*PROGRAM-NAME.fmt('%-16.16s');

't/pdf/samples/encrypt-40bit.pdf'.IO.copy('t/update-encrypted.pdf');

my PDF $pdf .= open: "t/update-encrypted.pdf", :password<owner>;

my $catalog = $pdf<Root>;
my $decoded = "BT /F1 16 Tf  40 250 Td (new page added to an encrypted PDF) Tj ET";

{
    my $Parent = $catalog<Pages>;
    my $Resources = $Parent<Kids>[0]<Resources>;
    my $MediaBox = $Parent<Kids>[0]<MediaBox>;
    my PDF::COS::Stream() $Contents = { :$decoded };
    $Parent<Kids>.push: { :Type( :name<Page> ), :$MediaBox, :$Resources, :$Parent, :$Contents };
    $Parent<Count>++;
}

$pdf.id = $id++;
lives-ok { $pdf.update }, 'doc.update lives';

lives-ok {$pdf = PDF.open: "t/update-encrypted.pdf"}, 'doc re-open lives';

ok $pdf<Encrypt><O>, 'document is encrypted';
is +$pdf<Root><Pages><Kids>, 2, 'document has two pages';
is $pdf<Root><Pages><Kids>[1]<Contents>.decoded, $decoded, 'decryption of new content';

done-testing;
