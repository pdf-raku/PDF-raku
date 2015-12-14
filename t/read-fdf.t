use v6;
use Test;

use PDF::Reader;
use PDF::DAO::Dict;

my $pdf-in = PDF::Reader.new();

$pdf-in.open( 't/pdf/pdf-fdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.type, 'FDF', 'loaded type';
my $trailer = $pdf-in.trailer<Root>;
isa-ok $trailer, PDF::DAO::Dict, 'root-obj';
is $trailer.obj-num, 1, 'root-obj.obj-num';
isa-ok $pdf-in.ind-obj(1, 0).object, PDF::DAO::Dict, 'fetch via index';

isa-ok $trailer<FDF>, Hash, '$trailer<FDF>';

is $trailer<FDF><F>, 'Document.pdf', '$trailer<FDF><F>';

isa-ok $trailer<FDF><Fields>, Array, '$tailer<FDF><Fields>';
is $trailer<FDF><Fields>[1]<T>, 'City', '$tailer<FDF><Fields>[1]<T>';

done-testing;

