use v6;
use Test;
plan 22;

use PDF::IO::IndObj;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::IO::Util;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-XRef.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;
my $ind-obj = PDF::IO::IndObj.new( |%ast, :$input );
my $xref-obj = $ind-obj.object;
does-ok $xref-obj, ::('PDF::DAO::Type')::('XRef');
is-json-equiv $xref-obj.W, [ 1, 2, 1], '$xref.new .W';
is $xref-obj.Size, 251, '$xref.new .Size';
is-json-equiv $xref-obj.Index, [ 214, 37], '$xref.new .Index';

my $xref;
lives-ok {$xref = $xref-obj.decode; }, 'basic content decode - lives';
isa-ok $xref.shape[0], Int, 'index is shaped';
my uint32 @expected-xref[37;3] = ([1, 16, 0], [1, 741, 0], [1, 1030, 0], [1, 1446, 0], [1, 2643, 0], [1, 3442, 0], [1, 4244, 0], [1, 5039, 0], [1, 5656, 0], [1, 6392, 0], [1, 7070, 0], [1, 7747, 0], [1, 8445, 0], [1, 11116, 0], [1, 17708, 0], [1, 19707, 0], [1, 34503, 0], [1, 116, 0], [2, 217, 0], [2, 217, 1], [2, 217, 2], [2, 217, 3], [2, 217, 4], [2, 217, 5], [2, 217, 6], [2, 217, 7], [2, 217, 8], [2, 217, 9], [2, 217, 10], [2, 217, 11], [2, 217, 12], [2, 217, 13], [2, 217, 14], [2, 217, 15], [2, 217, 16], [2, 217, 17], [1, 495, 0]);

is-json-equiv [$xref.list.rotor(3)], [@expected-xref.rotor(3)], 'decoded index as expected';
my $xref-recompressed = $xref-obj.encode;
my %ast2;
lives-ok {%ast2 = $ind-obj.ast }, '$.ast - lives';


my $ind-obj2 = PDF::IO::IndObj.new( |%ast2);
my $xref-roundtrip = $ind-obj2.object.decode( $xref-recompressed );

is-deeply $xref.values, $xref-roundtrip.values, 'encode/decode round-trip';

my $xref-index;
lives-ok { $xref-index = $ind-obj.object.decode-index; }, 'decode to index - lives';

my $expected-index-sample = [
    {:obj-num(248), :ref-obj-num(217), :index(16), :type(2)},
    {:obj-num(249), :type(2), :ref-obj-num(217), :index(17)},
    {:obj-num(250), :offset(495), :gen-num(0), :type(1)},
    ];

is-json-equiv [ $xref-index[*-3..*] ], $expected-index-sample, 'decoded index (sample)';

my $xref-recompressed-from-index = $ind-obj.object.encode-index($xref-index);
$xref-roundtrip = $ind-obj2.object.decode-index( $xref-recompressed-from-index );
is-json-equiv $xref-index, $xref-roundtrip, 'encode-index/decode-from-stage1 round-trip';

my $xref-new = ::('PDF::DAO::Type')::('XRef').new(:decoded(@expected-xref), :dict{ :Index[42, 37], :Size(37) } );
my $xref-roundtrip2 = $xref-new.decode( $xref-new.encode );
is-json-equiv $xref-new.W, [ 1, 2, 1], '$xref.new .W';
is $xref-new.Size, 37, '$xref.new .Size';
is-json-equiv $xref-new.Index, [ 42, 37], '$xref.new .Index';
is-deeply $xref.values, $xref-roundtrip2.values, '$xref.new round-trip';

my uint32 @decoded[2;3] = ([1, 16, 0], [1, 1 +< 16 , 1 +< 8]);
my $xref-wide = PDF::DAO.coerce( :stream{ :dict{ :Foo(:name<bar>), :Type(:name<XRef>) }, :@decoded} );
dies-ok {$xref-wide.encode}, 'encode incomplete setup';
$xref-wide.first-obj-num = 42;
$xref-wide<Size> = 2;
lives-ok {$xref-wide.encode}, 'encode completed setup';
is $xref-wide.Type, 'XRef', '$xref.new .Name auto-setup';
is-json-equiv $xref-wide.W, [ 1, 3, 2], '$xref.new .W auto-setup';
is-json-equiv $xref-wide.Index, [ 42, 2 ], '$xref.new .Index auto-setup';
is $xref-wide<Foo>, 'bar', ':dict constructor option';
