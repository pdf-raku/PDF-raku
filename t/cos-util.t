use v6;
use Test;
use PDF::Grammar::Test :&is-json-equiv;
plan 9;

use PDF::COS::Util :from-ast, :to-ast, :ast-coerce;

for (
     (my @ = [1.1, 2, '3']) => (:array[ 1.1, 2, :literal('3') ]),
     (my Numeric @ = [1.1, 2, 3e0]) => (:array[ 1.1, 2, 3e0 ]),
     (my Int @ = [1, 2, -3]) => (:array[ 1, 2, -3 ]),
     (my num @ = [1e0, 2e0, 3e0]) => (:array[ 1e0, 2e0, 3e0 ]),
     (my str @ = <x yy>) => (:array[ :literal<x>, :literal<yy> ]),
     (my uint8 @ = [10, 20, 30]) => (:array[ 10, 20, 30 ]),
     %( :a(10), :b[1, 2.1, 'x', ], :c(:name<x>) ) => (:dict{ :a(10), :b(:array($[1, 2.1, :literal("x")])), :c(:name("x")) }),
     [ True, False, Any, {}, ] => (:array[ True, False, Any, :dict{} ]),
     [ Hash, Array, Int, Str, Bool, DateTime ] => (:array[ Any xx 6 ]), 
  ) {
    my $v = .key;
    my $a = .value;
    my $ast = to-ast($v);
    is-json-equiv $ast, $a, "to ast {$v.raku}";
}
