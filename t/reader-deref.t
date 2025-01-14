use v6;
use Test;
plan 8;

use PDF::IO::Reader;
my PDF::IO::Reader $reader .= new;

sub deref($val is rw, *@ops) is rw {
    $reader.deref($val, |@ops);
}

$reader.open( 't/pdf/pdf.in' );

is-deeply $reader.get(1, 0), [1, 0, :dict{:Outlines(:ind-ref([2, 0])), :Pages(:ind-ref([3, 0])), :Type(:name<Catalog>)}], 'raw get';

my $catalog = $reader.trailer<Root>;

my $type = $reader.deref($catalog,<Type>);
is $type, 'Catalog', '$catalog<Type>';
$type = $reader.deref($type);
is $type, 'Catalog', '$catalog<Type>';

my $Pages := $reader.deref($catalog,<Pages> );
is $Pages<Type>, 'Pages', 'Pages<Type>';

my $Kids = $reader.deref($Pages,<Kids>);

for $reader.deref($Kids,[0]), $reader.deref($Kids, 0) -> $kid {
    is $kid<Type>, 'Page', 'Kids[0]<Type>';
}

ok $reader.deref($Pages,<Kids>,[0],<Parent>) === $Pages, '$Pages<Kids>[0]<Parent> === $Pages';

dies-ok {  $reader.deref($Pages, -1) }

done-testing;
