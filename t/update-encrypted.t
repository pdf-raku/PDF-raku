use v6;
use Test;
plan 5;

use PDF;

# ensure consistant document ID generation
srand(123456);

't/pdf-crypt-rc4.pdf'.IO.copy('t/update-encrypted.pdf');

my $pdf = PDF.open: "t/update-encrypted.pdf";

my $catalog = $pdf<Root>;
my $decoded = "BT /F1 16 Tf  40 250 Td (new page added to an encrypted PDF) Tj ET";

{
    my $Parent = $catalog<Pages>;
    my $Resources = $Parent<Kids>[0]<Resources>;
    my $MediaBox = $Parent<Kids>[0]<MediaBox>;
    my $Contents = PDF::COS.coerce( :stream{ :$decoded } );
    $Parent<Kids>.push: { :Type( :name<Page> ), :$MediaBox, :$Resources, :$Parent, :$Contents };
    $Parent<Count>++;
}

lives-ok { $pdf.update }, 'doc.update lives';

lives-ok {$pdf = PDF.open: "t/update-encrypted.pdf"}, 'doc re-open lives';

ok $pdf<Encrypt><O>, 'document is encrypted';
is +$pdf<Root><Pages><Kids>, 2, 'document has two pages';
is $pdf<Root><Pages><Kids>[1]<Contents>.decoded, $decoded, 'decryption of new content';

done-testing;
