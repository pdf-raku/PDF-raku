use v6;
use Test;
plan 14;

use PDF::Basic::IndObj::Stream;
use PDF::Basic::IndObj;

my $stream-obj;

my %dict = :Filter( :name<ASCIIHexDecode> ),
    :DecodeParms( :dict{ :BitsPerComponent( :int(4) ), :Predictor( :int(10) ), :Colors( :int(3) ) } );

lives_ok { $stream-obj = PDF::Basic::IndObj::Stream.new( :decoded("100 100 Td (Hello, world!) Tj"), :%dict, :obj-num(123), :gen-num(1)) }, 'basic stream object construction';
stream_tests( $stream-obj );

my $ind-obj-ast = $stream-obj.ast;

lives_ok { $stream-obj = PDF::Basic::IndObj.new-delegate( |%$ind-obj-ast ); }, 'stream object rebuilt';
stream_tests( $stream-obj );

sub stream_tests( $stream-obj) {
    isa_ok $stream-obj, PDF::Basic::IndObj::Stream;
    is $stream-obj.obj-num, 123, '$.obj-num';
    is $stream-obj.gen-num, 1, '$.gen-num';
    is_deeply $stream-obj.dict, %dict, 'stream object dictionary';
    is_deeply $stream-obj.decoded, '100 100 Td (Hello, world!) Tj', 'stream object decoded';
    is_deeply $stream-obj.encoded, '31303020313030205464202848656c6c6f2c20776f726c64212920546a', 'stream object encoded';
}

