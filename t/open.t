use v6;
use Test;

use PDF::Tools::Reader;

my $pdf-in = PDF::Tools::Reader.new(:debug).open( 't/pdf/pdf.in' );

is $pdf-in.version, 1.2, 'loaded version';
is $pdf-in.xref-offset, 559, 'loaded xref-offset';

done;

