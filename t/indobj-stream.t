use v6;
use Test;
plan 17;

use PDF::Object::Stream;
use PDF::Storage::IndObj;
use PDF::Grammar::Test :is-json-equiv;

my $stream-obj;

my %dict = ( :Filter<ASCIIHexDecode>,
             :DecodeParms( { :BitsPerComponent(4), :Predictor(10), :Colors(3) } ),
             :Length(58),
    );

my $decoded = '100 100 Td (Hello, world!) Tj';
my $encoded = '31303020313030205464202848656c6c6f2c20776f726c64212920546a';
lives-ok { $stream-obj = PDF::Object.compose( :$decoded, :stream{ :%dict } ) }, 'basic stream object construction';
stream_tests( $stream-obj );

my $ind-obj;
lives-ok { $ind-obj = PDF::Storage::IndObj.new( :ind-obj[123, 1, $stream-obj.content] ); }, 'stream object rebuilt';
is $ind-obj.obj-num, 123, '$.obj-num';
is $ind-obj.gen-num, 1, '$.gen-num';

stream_tests( $ind-obj.object );

$ind-obj.object.edit( :prepend('q '), :append(' Q'));
is $ind-obj.object.decoded, "q $decoded Q", '.edit';
is $ind-obj.object.encoded, "7120{$encoded}2051", '.edit + encoding';

$ind-obj.object.uncompress;
is-deeply $ind-obj.object.encoded, "q $decoded Q", 'stream object uncompressed';

$ind-obj.object.compress;
isnt $ind-obj.object.encoded,"q $decoded Q", 'stream object compressed';

$ind-obj.object.uncompress;
is-deeply $ind-obj.object.encoded, "q $decoded Q", 'stream object compressed, then uncompressed';

sub stream_tests( $stream-obj) {
    isa-ok $stream-obj, PDF::Object::Stream;
    is-json-equiv $stream-obj, %dict, 'stream object dictionary';
    is-deeply $stream-obj.decoded, '100 100 Td (Hello, world!) Tj', 'stream object decoded';
    is-deeply $stream-obj.encoded, $encoded, 'stream object encoded';
}
