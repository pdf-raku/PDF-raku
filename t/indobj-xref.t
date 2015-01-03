use v6;
use Test;

plan 4;

use PDF::Basic::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Basic;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-XRef.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Basic::IndObj.indobj-new( |%$ast, :$input );
isa_ok $ind-obj, ::('PDF::Basic::IndObj')::('XRef');

my $xref;
lives_ok { $xref = $ind-obj.decode }, 'basic content decode - lives';

my $expected-xref = [[1, 16, 0], [1, 741, 0], [1, 1030, 0], [1, 1446, 0], [1, 2643, 0], [1, 3442, 0], [1, 4244, 0], [1, 5039, 0], [1, 5656, 0], [1, 6392, 0], [1, 7070, 0], [1, 7747, 0], [1, 8445, 0], [1, 11116, 0], [1, 17708, 0], [1, 19707, 0], [1, 34503, 0], [1, 116, 0], [2, 217, 0], [2, 217, 1], [2, 217, 2], [2, 217, 3], [2, 217, 4], [2, 217, 5], [2, 217, 6], [2, 217, 7], [2, 217, 8], [2, 217, 9], [2, 217, 10], [2, 217, 11], [2, 217, 12], [2, 217, 13], [2, 217, 14], [2, 217, 15], [2, 217, 16], [2, 217, 17], [1, 495, 0]];

is_deeply $xref, $expected-xref, 'decoded index as expected';
my $xref-recompressed = $ind-obj.encode;

my $ind-obj2 = PDF::Basic::IndObj.indobj-new( |%$ast);
my $xref-roundtrip = $ind-obj2.decode( $xref-recompressed );

is_deeply $xref, $xref-roundtrip, 'encode/decode round-trip';

