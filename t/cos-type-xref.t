use v6;
use Test;
plan 24;

use PDF::IO::IndObj;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::IO::Util;

my PDF::Grammar::PDF::Actions $actions .= new;

my $input = 't/pdf/ind-obj-XRef.in'.IO.slurp( :bin ).decode: "latin-1";
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;
my PDF::IO::IndObj $ind-obj .= new( |%ast, :$input );
my $xref-obj = $ind-obj.object;
does-ok $xref-obj, ::('PDF::COS::Type')::('XRef');
is-json-equiv $xref-obj.W, [ 1, 2, 1], '$xref.new .W';
is $xref-obj.Size, 251, '$xref.new .Size';
is-json-equiv $xref-obj.Index, [ 214, 35, 1000, 2], '$xref.new .Index';

my $xref;
lives-ok {$xref = $xref-obj.decode; }, 'basic content decode - lives';
isa-ok $xref.shape[0], Int, 'index is shaped';
my uint64 @expected-xref[37;3] = ([1, 16, 0], [1, 741, 0], [1, 1030, 0], [1, 1446, 0], [1, 2643, 0], [1, 3442, 0], [1, 4244, 0], [1, 5039, 0], [1, 5656, 0], [1, 6392, 0], [1, 7070, 0], [1, 7747, 0], [1, 8445, 0], [1, 11116, 0], [1, 17708, 0], [1, 19707, 0], [1, 34503, 0], [1, 116, 0], [2, 217, 0], [2, 217, 1], [2, 217, 2], [2, 217, 3], [2, 217, 4], [2, 217, 5], [2, 217, 6], [2, 217, 7], [2, 217, 8], [2, 217, 9], [2, 217, 10], [2, 217, 11], [2, 217, 12], [2, 217, 13], [2, 217, 14], [2, 217, 15], [2, 217, 16], [2, 217, 17], [1, 495, 0]);

is-json-equiv [$xref.list.rotor(3)], [@expected-xref.rotor(3)], 'decoded index as expected';
lives-ok {$xref-obj.check}, '.check lives';
my $xref-recompressed = $xref-obj.encode;
my %ast2;
lives-ok {%ast2 = $ind-obj.ast }, '$.ast - lives';


my PDF::IO::IndObj $ind-obj2 .= new( |%ast2);
my $xref-roundtrip = $ind-obj2.object.decode( $xref-recompressed );

is-deeply $xref.values, $xref-roundtrip.values, 'encode/decode round-trip';

my $xref-index;
lives-ok { $xref-index = $ind-obj.object.decode-index; }, 'decode to index - lives';

my $expected-tail-seg = ((1000, 2, 217, 17), (1001, 1, 495, 0));

is-deeply $xref-index.rotor(4).tail(2), $expected-tail-seg, 'decoded index final segment';

my $xref-recompressed-from-index = $ind-obj.object.encode-index($xref-index);
$xref-roundtrip = $ind-obj2.object.decode-index( $xref-recompressed-from-index );
is-deeply $xref-index.rotor(4), $xref-roundtrip.rotor(4), 'encode-index/decode-from-stage1 round-trip';

my $xref-new = ::('PDF::COS::Type')::('XRef').new(:decoded(@expected-xref), :dict{ :Index[42, 37], :Size(37) } );
my $xref-roundtrip2 = $xref-new.decode( $xref-new.encode );
is-json-equiv $xref-new.W, [ 1, 2, 1], '$xref.new .W';
is $xref-new.Size, 37, '$xref.new .Size';
is-json-equiv $xref-new.Index, [ 42, 37], '$xref.new .Index';
is-deeply $xref.values, $xref-roundtrip2.values, '$xref.new round-trip';

my uint64 @decoded[2;3] = [1, 16, 0], [1, 1 +< 16 , 1 +< 8];
my PDF::COS $xref-wide .= coerce( :stream{ :dict{ :Foo(:name<bar>), :Type(:name<XRef>) }, :@decoded} );
dies-ok {$xref-wide.encode}, 'encode incomplete setup';
$xref-wide.first-obj-num = 42;
$xref-wide<Size> = 2;
lives-ok {$xref-wide.encode}, 'encode completed setup';
is $xref-wide.Type, 'XRef', '$xref.new .Name auto-setup';
is-json-equiv $xref-wide.W, [ 1, 3, 2], '$xref.new .W auto-setup';
is-json-equiv $xref-wide.Index, [ 42, 2 ], '$xref.new .Index auto-setup';
is $xref-wide<Foo>, 'bar', ':dict constructor option';

my @values = (1, 1,0,  2, 1,1,  3, 0,255);
my Str $encoded = buf8.new(@values).decode: "latin-1";
my PDF::COS $xref-narrow .= coerce( :stream{ :dict{ :Foo(:name<bar>), :Type(:name<XRef>), :W[0,1,0,2,0], :Size(3) }, :$encoded} );
is [$xref-narrow.decoded.values], [0,1,0,256,0, 0,2,0,257,0, 0,3,0,255,0], 'zero width in /W';
