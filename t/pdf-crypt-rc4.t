use v6;
use Test;
plan 15;

use PDF;

# ensure consistant document ID generation
srand(123456);

my $pdf = PDF.open: "t/pdf/samples/00helloworld.pdf";

my $user-pass = '';
my $owner-pass = 'ssh!';
my $expected-contents = 'BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET';
my $expected-author = 'PDF-Tools';

lives-ok { $pdf.encrypt( :$owner-pass, :$user-pass, :R(2), :V(1), ); }, '$pdf.encrypt (R2.1) - lives';
is $pdf.crypt.is-owner, True, 'newly encrypted pdf - is-owner';
lives-ok {$pdf.save-as: "t/pdf-crypt-rc4.pdf"}, '$pdf.save-as .pdf - lives';
lives-ok {$pdf.save-as: "t/pdf-crypt-rc4.json"}, '$pdf.save-as .json - lives';
dies-ok { $pdf = PDF.open: "t/encrypt.pdf", :password<dunno> }, "open encrypted with incorrect password - dies";

lives-ok { $pdf = PDF.open("t/pdf-crypt-rc4.pdf", :password($user-pass)) }, 'open with user password - lives';
is $pdf.crypt.is-owner, False, 'open with user password - not is-owner';
is $pdf<Info><Author>, $expected-author, 'open with user password - .Info.Author';
is $pdf<Root><Pages><Kids>[0]<Contents>.decoded, $expected-contents, 'open with user password - contents';

lives-ok { $pdf = PDF.open("t/pdf-crypt-rc4.pdf", :password($owner-pass)) }, 'open with owner password - lives';
is $pdf.crypt.is-owner, True, 'open with owner password - is-owner';
is $pdf<Info><Author>, $expected-author, 'open with owner password - .Info.Author';
is $pdf<Root><Pages><Kids>[0]<Contents>.decoded, $expected-contents, 'open with owner password - contents';

dies-ok { $pdf = PDF.open: "t/pdf-crypt-rc4.json", :password<dunno> }, "open encrypted json with incorrect password - dies";

lives-ok { $pdf = PDF.open("t/pdf-crypt-rc4.json", :password($user-pass)) }, 'open json user password - lives';

done-testing;
