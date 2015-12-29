use v6;
use Test;
plan 24;

use PDF::DAO::Stream;
use PDF::Storage::IndObj;
use PDF::Grammar::Test :is-json-equiv;

my $stream-obj;

my %dict = ( :Filter<ASCIIHexDecode>,
             :DecodeParms{ :BitsPerComponent(4), :Predictor(10), :Colors(3) },
    );

my $decoded = '100 100 Td (Hello, world!) Tj';
my $encoded = '31303020313030205464202848656c6c6f2c20776f726c64212920546a';
lives-ok { $stream-obj = PDF::DAO.coerce( :$decoded, :stream{ :%dict } ) }, 'basic stream object construction';
stream_tests( $stream-obj, 'stream object' );
%dict<Length> = 58;
stream_tests( $stream-obj.clone, 'stream object cloned' );

my $ind-obj;
lives-ok { $ind-obj = PDF::Storage::IndObj.new( :ind-obj[123, 1, $stream-obj.content] ); }, 'stream object rebuilt';
is $ind-obj.obj-num, 123, '$.obj-num';
is $ind-obj.gen-num, 1, '$.gen-num';

stream_tests( $ind-obj.object, 'indirect object' );

dies-ok {$ind-obj.object.edit-stream( :append(0xABC.chr))}, 'illelal character in edit - dies';

$ind-obj.object.edit-stream( :prepend('q '), :append(' Q'));
is $ind-obj.object.decoded, "q $decoded Q", '.edit';
is $ind-obj.object.encoded, "7120{$encoded}2051", '.edit + encoding';

$ind-obj.object.uncompress;
is-deeply $ind-obj.object.encoded, "q $decoded Q", 'stream object uncompressed';

$ind-obj.object.compress;
isnt $ind-obj.object.encoded,"q $decoded Q", 'stream object compressed';

$ind-obj.object.uncompress;
is-deeply $ind-obj.object.encoded, "q $decoded Q", 'stream object compressed, then uncompressed';

sub stream_tests( $stream-obj, $subject) {
    isa-ok $stream-obj, PDF::DAO::Stream, $subject;
    is-json-equiv $stream-obj, %dict, $subject~' dictionary';
    is $stream-obj.decoded, '100 100 Td (Hello, world!) Tj', $subject~' decoded';
    is $stream-obj.encoded, $encoded, $subject~' encoded';
}

my $stream2 = PDF::DAO.coerce( :stream{  :dict{ :Foo( :name<Bar> ) } } );
is-json-equiv $stream2.content, (:dict{:Foo(:name<Bar>)}), 'stream without content';
$stream2.decoded = 'ABC12345678';
is-json-equiv $stream2.content, (:stream{ :dict{:Foo(:name<Bar>), :Length{ :int(11) } }, :encoded<ABC12345678> }), 'stream with content'
