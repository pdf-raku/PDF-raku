use v6;
use Test;
plan 13;

use PDF::IO::IndObj;
use PDF::COS::Name;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test :is-json-equiv;

my subset MyName of PDF::COS::Name where 'Foo' | 'Bar' | 'Baz';
lives-ok {MyName.COERCE( 'Foo')}, 'coerce to name subset';
nok 'Foo' ~~ MyName, "role hasn't leaked";

enum « :Baz<Baz> »;
my MyName() $baz;
lives-ok { $baz = Baz; }, 'coerce to enum lives';
does-ok $baz, PDF::COS::Name, 'coerce to enum is name';
is-deeply $baz.content, (:name<Baz>), 'content';

my PDF::Grammar::PDF::Actions $actions .= new;
my $input = '42 5 obj /HiThere endobj';
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;
my PDF::IO::IndObj $ind-obj .= new( |%ast, :$input );
isa-ok $ind-obj.object, Str;
is $ind-obj.object, 'HiThere', '.object';
is $ind-obj.obj-num, 42, '$.obj-num';
is $ind-obj.gen-num, 5, '$.gen-num';
is-json-equiv $ind-obj.object, 'HiThere', '$.object';
my $content = $ind-obj.content;
isa-ok $content, Pair;
is-deeply $content, (:name<HiThere>), '$.content';
is-json-equiv $ind-obj.ast, %ast, 'ast regeneration';

