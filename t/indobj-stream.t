use v6;
use Test;
plan 12;

use PDF::Object::Stream;
use PDF::Tools::IndObj;
use PDF::Grammar::Test :is-json-equiv;

my $stream-obj;

my %dict = ( :Filter<ASCIIHexDecode>,
             :DecodeParms( { :BitsPerComponent(4), :Predictor(10), :Colors(3) } ),
    );

lives_ok { $stream-obj = PDF::Object::Stream.new( :decoded("100 100 Td (Hello, world!) Tj"), :%dict, :obj-num(123), :gen-num(1)) }, 'basic stream object construction';
stream_tests( $stream-obj );

my $ind-obj;
lives_ok { $ind-obj = PDF::Tools::IndObj.new( :ind-obj[123, 1, $stream-obj.content] ); }, 'stream object rebuilt';
is $ind-obj.obj-num, 123, '$.obj-num';
is $ind-obj.gen-num, 1, '$.gen-num';
stream_tests( $ind-obj.object );

sub stream_tests( $stream-obj) {
    isa_ok $stream-obj, PDF::Object::Stream;
    is-json-equiv $stream-obj.dict, %dict, 'stream object dictionary';
    is_deeply $stream-obj.decoded, '100 100 Td (Hello, world!) Tj', 'stream object decoded';
    is_deeply $stream-obj.encoded, '31303020313030205464202848656c6c6f2c20776f726c64212920546a', 'stream object encoded';
}

