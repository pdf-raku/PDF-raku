use v6;
use Test;
plan 6;

use PDF;

# ensure consistant document ID generation
srand(123456);

my PDF $pdf .= open: "t/pdf/samples/encrypt-40bit.pdf", :password<owner>;

$pdf.Info.Title = 're-encrypted';

lives-ok {$pdf.encrypt( :owner-pass<re-encrypted>, :aes);}, 'reencrypt';

dies-ok { $pdf.update }, 'update is not permitted';

lives-ok {$pdf.save-as: "t/pdf-reencrypt.pdf"}, 'save-as is permitted';

lives-ok {$pdf .= open: "t/pdf-reencrypt.pdf"}, 'open lives';

ok ($pdf.crypt.defined && $pdf.Encrypt.defined), 'PDF is encrypted';

is $pdf.Info.Title, 're-encrypted', 'decrypted text';

done-testing;
