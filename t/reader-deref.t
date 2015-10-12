use v6;
use Test;

use PDF::Reader;
use PDF::Writer;
use PDF::DAO;

sub prefix:</>($name){ PDF::DAO.coerce(:$name) };

my $reader = PDF::Reader.new(:debug);

sub deref($val is rw, *@ops) is rw {
    $reader.deref($val, |@ops);
}

$reader.open( 't/pdf/pdf.in' );

my $catalog = $reader.trailer<Root>;

my $type = $reader.deref($catalog,<Type>);
is $type, 'Catalog', '$catalog<Type>';

my $Pages := $reader.deref($catalog,<Pages> );
is $Pages<Type>, 'Pages', 'Pages<Type>';

my $Kids = $reader.deref($Pages,<Kids>);

my $kid := $reader.deref($Kids,[0]);
is $kid<Type>, 'Page', 'Kids[0]<Type>';

is $reader.deref($Pages,<Kids>,[0],<Parent>).WHERE, $Pages.WHERE, '$Pages<Kids>[0]<Parent>.WHERE == $Pages.WHERE';

done-testing;
