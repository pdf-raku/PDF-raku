use v6;
use Test;

use PDF::DAO::Doc;

# ensure consistant document ID generation
srand(123456);

my $doc = PDF::DAO::Doc.open: "t/helloworld.pdf";

my $user-pass = '';
my $owner-pass = 'ssh!';
my $expected-contents = 'BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET';
my $expected-author = 'PDF-Tools/t/helloworld.t';

lives-ok { $doc.encrypt( :$owner-pass, :$user-pass, :R(2), :V(1), ) }, '$doc.encrypt (R2.1) - lives';
is $doc.crypt.is-owner, True, 'newly encrypted pdf - is-owner';
lives-ok {$doc.save-as: "t/encrypt.pdf"}, '$doc.save-as - lives';
dies-ok { $doc = PDF::DAO::Doc.open: "t/encrypt.pdf", :password<dunno> }, "open encrypted with incorrect password - dies";

lives-ok { $doc = PDF::DAO::Doc.open("t/encrypt.pdf", :password($user-pass)) }, 'open with user password - lives';
is $doc.crypt.is-owner, False, 'open with user password - not is-owner';
is $doc<Info><Author>, $expected-author, 'open with user password - .Info.Author';
is $doc<Root><Pages><Kids>[0]<Contents>.decoded, $expected-contents, 'open with user password - contents';

lives-ok { $doc = PDF::DAO::Doc.open("t/encrypt.pdf", :password($owner-pass)) }, 'open with owner password - lives';
is $doc.crypt.is-owner, True, 'open with owner password - is-owner';
is $doc<Info><Author>, $expected-author, 'open with owner password - .Info.Author';
is $doc<Root><Pages><Kids>[0]<Contents>.decoded, $expected-contents, 'open with owner password - contents';

done-testing;
