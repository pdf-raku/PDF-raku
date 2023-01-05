use v6;
use Test;
plan 4;

use PDF::IO::Reader;
my PDF::IO::Reader $reader .= new;

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

ok $reader.deref($Pages,<Kids>,[0],<Parent>) === $Pages, '$Pages<Kids>[0]<Parent> === $Pages';

done-testing;
