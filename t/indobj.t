use v6;
use Test;
plan 4;

use PDF::Basic::IndObj::Stream;

my $stream-obj;

my %dict = :Filter( :name<ASCIIHexDecode> ),
    :DecodeParms( :dict{ :BitsPerComponent( :int(4) ), :Predictor( :int(10) ), :Colors( :int(3) ) } );

lives_ok { $stream-obj = PDF::Basic::IndObj::Stream.new( :decoded("100 100 Td (Hello, world!) Tj"), :%dict) }, 'basic stream object construction';

is_deeply $stream-obj.dict, %dict, 'stream object dictionary';
is_deeply $stream-obj.decoded, '100 100 Td (Hello, world!) Tj', 'stream object decoded content';
is_deeply $stream-obj.encoded, '31303020313030205464202848656c6c6f2c20776f726c64212920546a', 'stream object encoded content';

