use v6;
use Test;
use PDF::DAO::Doc;

# ensure consistant document ID generation
srand(123456);

't/pdf/samples/encrypt-40bit.pdf'.IO.copy('t/update-encrypted.pdf');

my $doc = PDF::DAO::Doc.open: "t/update-encrypted.pdf";

my $catalog = $doc<Root>;
my $decoded = "BT /F1 16 Tf  40 250 Td (new page added to an encrypted PDF) Tj ET";

{
    my $Parent = $catalog<Pages>;
    my $Resources = $Parent<Kids>[0]<Resources>;
    my $MediaBox = $Parent<Kids>[0]<MediaBox>;
    my $Contents = PDF::DAO.coerce( :stream{ :$decoded } );
    $Parent<Kids>.push: { :Type( :name<Page> ), :$MediaBox, :$Resources, :$Parent, :$Contents };
    $Parent<Count>++;
}

lives-ok { $doc.update }, 'doc.update lives';

lives-ok {$doc = PDF::DAO::Doc.open: "t/update-encrypted.pdf"}, 'doc re-open lives';

is +$doc<Root><Pages><Kids>, 2, 'document has two pages';
is $doc<Root><Pages><Kids>[1]<Contents>.decoded, $decoded, 'decryption of new content';

done-testing;
