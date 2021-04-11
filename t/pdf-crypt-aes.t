use v6;
use Test;
plan 10;

use PDF;
use PDF::COS::Type::Encrypt :PermissionsFlag;
# ensure consistant document ID generation

my PDF $pdf .= open: "t/pdf/samples/00helloworld.pdf";

my $user-pass = '';
my $owner-pass = 'ssh!';
my $expected-contents = 'BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET';
my $expected-author = 'PDF-Tools';

my $P = 2 +< (PermissionsFlag::All - 2);
lives-ok { $pdf.encrypt( :$owner-pass, :$user-pass, :aes, :$P ); }, '$pdf.encrypt (AES) - lives';
is $pdf.crypt.is-owner, True, 'newly encrypted pdf - is-owner';
lives-ok {$pdf.save-as: "tmp/pdf-crypt-aes.pdf";}, '$pdf.save-as - lives';
dies-ok { $pdf .= open: "tmp/pdf-crypt-aes.pdf", :password<dunno> }, "open encrypted with incorrect password - dies";

lives-ok { $pdf .= open("tmp/pdf-crypt-aes.pdf", :password($user-pass)) }, 'open with user password - lives';
is $pdf.crypt.is-owner, False, 'open with user password - not is-owner';
is $pdf<Info><Author>, $expected-author, 'open with user password - .Info.Author';
is $pdf<Root><Pages><Kids>[0]<Contents>.decoded, $expected-contents, 'open with user password - contents';

sub permitted($pdf, UInt $flag --> Bool) {

    return True
        if $pdf.crypt.?is-owner;

    with $pdf.Encrypt {
        .permitted($flag);
    }
    else {
        True;
    }
}

ok permitted($pdf, PermissionsFlag::Print), 'user permitted action';
ok permitted($pdf, PermissionsFlag::Copy), 'another user permitted action';
done-testing;
