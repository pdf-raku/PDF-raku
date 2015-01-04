use Test;
use PDF::Core::Writer;
use PDF::Core::Filter::ASCIIHex;
use PDF::Core::Filter::Flate;
use PDF::Core::Filter::RunLength;

pass('compiles');

done;
