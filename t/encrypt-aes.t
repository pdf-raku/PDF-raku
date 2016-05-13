use v6;
use Test;

use PDF::DAO::Doc;

# ensure consistant document ID generation
srand(123456);

my $doc = PDF::DAO::Doc.open: "t/helloworld.pdf";

my $user-pass = '';
my $owner-pass = 'ssh!';
my $expected-contents = 'BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET';
my $expected-author = 'PDF-Tools/t/dao-doc.t';

lives-ok { $doc.encrypt( :$owner-pass, :$user-pass, :aes ); }, '$doc.encrypt (AES) - lives';
is $doc.crypt.is-owner, True, 'newly encrypted pdf - is-owner';
##lives-ok {
$doc.save-as: "t/encrypt-aes.pdf";##}, '$doc.save-as - lives';
dies-ok { $doc = PDF::DAO::Doc.open: "t/encrypt-aes.pdf", :password<dunno> }, "open encrypted with incorrect password - dies";

lives-ok { $doc = PDF::DAO::Doc.open("t/encrypt-aes.pdf", :password($user-pass)) }, 'open with user password - lives';
is $doc.crypt.is-owner, False, 'open with user password - not is-owner';
is $doc<Info><Author>, $expected-author, 'open with user password - .Info.Author';
is $doc<Root><Pages><Kids>[0]<Contents>.decoded, $expected-contents, 'open with user password - contents';

done-testing;
