use v6;
use Test;
plan 17;

use PDF;
use PDF::COS::Type::Encrypt :PermissionsFlag;

my PDF $pdf .= open: "t/pdf/samples/00helloworld.pdf";

my $user-pass = '';
my $owner-pass = 'ssh!';
my $expected-contents = 'BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET';
my $expected-author = 'PDF-Tools';

my $P = 2 +< (PermissionsFlag::Print - 2);
lives-ok { $pdf.encrypt( :$owner-pass, :$user-pass, :R(2), :V(1), :$P); }, '$pdf.encrypt (R2.1) - lives';
is $pdf.crypt.is-owner, True, 'newly encrypted pdf - is-owner';
lives-ok {$pdf.save-as: "tmp/pdf-crypt-rc4.pdf"}, '$pdf.save-as .pdf - lives';
lives-ok {$pdf.save-as: "tmp/pdf-crypt-rc4.json"}, '$pdf.save-as .json - lives';
dies-ok { $pdf .= open: "tmp/pdf-crypt-rc4.pdf", :password<dunno> }, "open encrypted with incorrect password - dies";

lives-ok { $pdf .= open("tmp/pdf-crypt-rc4.pdf", :password($user-pass)) }, 'open with user password - lives';
is $pdf.crypt.is-owner, False, 'open with user password - not is-owner';
is $pdf<Info><Author>, $expected-author, 'open with user password - .Info.Author';
is $pdf<Root><Pages><Kids>[0]<Contents>.decoded, $expected-contents, 'open with user password - contents';

sub permitted($pdf, UInt $flag --> Bool) {

    return True
        if $pdf.crypt.?is-owner;

    with $pdf.Encrypt {
        .permitted($flag)
    }
    else {
        True;
    }
}

ok permitted($pdf, PermissionsFlag::Print), 'user permitted action';
nok permitted($pdf, PermissionsFlag::Copy), 'user not permitted action';

lives-ok { $pdf .= open("tmp/pdf-crypt-rc4.pdf", :password($owner-pass)) }, 'open with owner password - lives';
is $pdf.crypt.is-owner, True, 'open with owner password - is-owner';
is $pdf<Info><Author>, $expected-author, 'open with owner password - .Info.Author';
is $pdf<Root><Pages><Kids>[0]<Contents>.decoded, $expected-contents, 'open with owner password - contents';

dies-ok { $pdf .= open: "tmp/pdf-crypt-rc4.json", :password<dunno> }, "open encrypted json with incorrect password - dies";

lives-ok { $pdf .= open("tmp/pdf-crypt-rc4.json", :password($user-pass)) }, 'open json user password - lives';

done-testing;
