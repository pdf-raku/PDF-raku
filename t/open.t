use v6;
use Test;

use PDF::Tools;

my $pdf = PDF::Tools.new(:debug).open( 't/pdf/pdf.in' );

is $pdf.version, 1.2, 'loaded version';
is $pdf.xref-offset, 559, 'loaded xref-offset';

done;

