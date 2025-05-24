use v6;
use Test;
plan 13;

use PDF::IO::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test :is-json-equiv;

my PDF::Grammar::PDF::Actions $actions .= new: :lite;

my $input = '42 5 obj [0.9505 1.0000 1.0890 [1 2 (abc)]] endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;
my PDF::IO::IndObj $ind-obj .= new( |%ast, :$input );
my $object = $ind-obj.object;
isa-ok $object, Array;
is-json-equiv $object, [0.9505e0, 1e0, 1.089e0, [1, 2, "abc"]], '$.content';
is $ind-obj.obj-num, 42, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
my $content = $ind-obj.content;
isa-ok $content, Pair;
is-json-equiv $content, ( :array[0.9505e0, 1e0, 1.089e0,
                             :array[1, 2, :literal<abc>],
                     ]), '$.content';

is-json-equiv $ind-obj.ast, %ast, 'ast regeneration';

use PDF::COS::Array;
use PDF::COS::Tie;
use PDF::COS::Tie::Hash;

role ColorSpaceDict does PDF::COS::Tie::Hash {
     method yay{42}
}

class ColorSpaceArray
    is PDF::COS::Array {

    method type {'ColorSpace'}
    has Str $.Subtype is index(0);
    has ColorSpaceDict $.Dict is index(1);
}

my ColorSpaceArray $cs .= new;
$cs[0] = 'Lab';
$cs[1] = { :WhitePoint[1.0, 1.0, 1.0] };

is $cs.Subtype, 'Lab', 'tied index [0]';
is-json-equiv $cs.Dict, { :WhitePoint[1.0, 1.0, 1.0] }, 'tied index [1]';
ok $cs.Dict.does(ColorSpaceDict), 'tied index "does" attribute';
is $cs.Dict.yay, 42, 'tied index method call';
lives-ok {$cs.Subtype = 'CalRGB'}, 'tied index assignment';
is $cs.Subtype, 'CalRGB', 'tied index fetch';
