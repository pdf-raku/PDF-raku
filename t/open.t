use v6;
use Test;

use PDF::Core;

my $pdf = PDF::Core.new(:debug).open( 't/pdf/pdf.in' );

is $pdf.version, 1.2, 'loaded version';
is $pdf.xref-offset, 559, 'loaded xref-offset';

done;

