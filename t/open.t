use v6;
use Test;

use PDF::Tools::Reader;

my $pdf-in = PDF::Tools::Reader.new(:debug);

$pdf-in.open( 't/pdf/pdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.xref-offset, 559, 'loaded xref-offset';
is_deeply $pdf-in.root-obj, (:ind-ref[1, 0]), '$.root-obj';
is_deeply [$pdf-in.ind-obj-idx], [{"gen" => 0, "offset" => 13}, {"offset" => 78, "gen" => 0}, {"gen" => 0, "offset" => 124}, {"offset" => 183, "gen" => 0}, {"offset" => 326, "gen" => 0}, {"offset" => 421, "gen" => 0}, {"offset" => 451, "gen" => 0}], '$.ind-obj-idx';

done;

