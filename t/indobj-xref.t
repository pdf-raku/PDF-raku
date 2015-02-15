use v6;
use Test;

plan 16;

use PDF::Tools::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-XRef.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = %( $/.ast );
my $ind-obj = PDF::Tools::IndObj.new-delegate( |%ast, :$input );
isa_ok $ind-obj, ::('PDF::Tools::IndObj')::('XRef');
is_deeply $ind-obj.W, (:array[ :int(1), :int(2), :int(1)]), '$xref.new .W';
is_deeply $ind-obj.Size, (:int(251)), '$xref.new .Size';
is_deeply $ind-obj.Index, (:array[ :int(214), :int(37)]), '$xref.new .Index';

my $xref;
lives_ok { $xref = $ind-obj.decode }, 'basic content decode - lives';

my $expected-xref = [[1, 16, 0], [1, 741, 0], [1, 1030, 0], [1, 1446, 0], [1, 2643, 0], [1, 3442, 0], [1, 4244, 0], [1, 5039, 0], [1, 5656, 0], [1, 6392, 0], [1, 7070, 0], [1, 7747, 0], [1, 8445, 0], [1, 11116, 0], [1, 17708, 0], [1, 19707, 0], [1, 34503, 0], [1, 116, 0], [2, 217, 0], [2, 217, 1], [2, 217, 2], [2, 217, 3], [2, 217, 4], [2, 217, 5], [2, 217, 6], [2, 217, 7], [2, 217, 8], [2, 217, 9], [2, 217, 10], [2, 217, 11], [2, 217, 12], [2, 217, 13], [2, 217, 14], [2, 217, 15], [2, 217, 16], [2, 217, 17], [1, 495, 0]];

is_deeply $xref, $expected-xref, 'decoded index as expected';
my $xref-recompressed = $ind-obj.encode;

my %ast2;
lives_ok { %ast2 = %( $ind-obj.ast ) }, '$.ast - lives';

my $ind-obj2 = PDF::Tools::IndObj.new-delegate( |%ast2);
my $xref-roundtrip = $ind-obj2.decode( $xref-recompressed );

is_deeply $xref, $xref-roundtrip, 'encode/decode round-trip';

my $xref-new = ::('PDF::Tools::IndObj')::('XRef').new(:decoded($expected-xref));
$xref-new.first-obj-num = 42;
$xref-new.next-obj-num = 214;
my $xref-roundtrip2 = $xref-new.decode( $xref-new.encode );
is_deeply $xref-new.W, (:array[ :int(1), :int(2), :int(1)]), '$xref.new .W';
is_deeply $xref-new.Size, (:int(214)), '$xref.new .Size';
is_deeply $xref-new.Index, (:array[ :int(42), :int(37)]), '$xref.new .Index';

is_deeply $xref, $xref-roundtrip2, '$xref.new round-trip';

my $xref-wide = ::('PDF::Tools::IndObj')::('XRef').new(:dict{Foo => :int(42)}, :decoded[[1, 16, 0], [1, 1 +< 16 , 1 +< 8]] );
is_deeply $xref-wide.W, (:array[ :int(1), :int(3), :int(2)]), '$xref.new .W auto-resized';
is_deeply $xref-wide.dict<Foo>, (:int(42)), ':dict consrtuctor option';

dies_ok {$xref-wide.encode}, 'encode incomplete setup';
$xref-wide.first-obj-num = 42;
$xref-wide.next-obj-num = 214;
lives_ok {$xref-wide.encode}, 'encode completed setup';
