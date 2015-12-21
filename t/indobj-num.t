use v6;
use Test;

plan 23;

use PDF::Storage::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test :is-json-equiv;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = '37 5 obj 42 endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%ast, :$input );
isa-ok $ind-obj.object, Int;
does-ok $ind-obj.object, ::('PDF::DAO::Int');
is $ind-obj.obj-num, 37, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
isa-ok $ind-obj.object, Int, '$.object';
is $ind-obj.object, 42, '$.object';
my $content = $ind-obj.content;
isa-ok $content, Pair;
is-json-equiv $content, (:int(42)), '$.content';

is $ind-obj.object.flag-is-set(2), True, 'flag 2 is set'; is
$ind-obj.object.flag-is-set(3), False, 'flag 3 is unset';

is-json-equiv $ind-obj.ast, %ast, 'ast regeneration';

my $twos-comp-mask = PDF::DAO.coerce( :int(-44) );
is $twos-comp-mask.flag-is-set(3), True, 'twos-comp flag 3 is set';
is $twos-comp-mask.flag-is-set(4), False, 'twos-comp flag 4 is unset';
is $twos-comp-mask.flag-is-set(5), True, 'twos-comp flag 5 is set';

$input = '5 6 obj 4.2 endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
%ast = $/.ast;
$ind-obj = PDF::Storage::IndObj.new( |%ast, :$input );
isa-ok $ind-obj.object, Rat;
does-ok $ind-obj.object, ::('PDF::DAO::Real');
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 6, '$.gen-num';
isa-ok $ind-obj.object, Rat, '$.object';
is $ind-obj.object, 4.2, '$.object';
$content = $ind-obj.content;
isa-ok $content, Pair;
is-json-equiv $content, (:real(4.2)), '$.content';
is-json-equiv $ind-obj.ast, %ast, 'ast regeneration';

