use v6;
use Test;

plan 6;

use PDF::Basic::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Basic;
use PDF::Basic::Util :unbox;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '42 5 obj [0.9505 1.0000 1.0890 [1 2 (abc)]] endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Basic::IndObj.indobj-new( |%$ast, :$input );
isa_ok $ind-obj, ::('PDF::Basic::IndObj')::('Array');
is $ind-obj.obj-num, 42, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
my $array = $ind-obj.decoded;
isa_ok $array, Array;
is_deeply unbox( :$array ), [0.9505e0, 1e0, 1.089e0, [1, 2, "abc"]], '$.decoded';

my $encoded = $ind-obj.encoded;
my $ind-obj2 = PDF::Basic::IndObj.indobj-new( |%$ast, :$encoded );

is_deeply $ind-obj2.decoded, $array, 'encode/decode round-trip';
