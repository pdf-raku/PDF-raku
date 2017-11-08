use v6;
use Test;
plan 8;

use PDF::DAO::Util :from-ast, :to-ast, :ast-coerce;

for (
     (my @ = [1.1, 2, '3']) => (:array[ :real(1.1), :int(2), :literal('3') ]),
     (my Numeric @ = [1.1, 2, 3e0]) => (:array[ :real(1.1), :real(2), :real(3e0) ]),
     (my Int @ = [1, 2, -3]) => (:array[ :int(1), :int(2), :int(-3) ]),
     (my num @ = [1e0, 2e0, 3e0]) => (:array[ :real(1e0), :real(2e0), :real(3e0) ]),
     (my str @ = <x yy>) => (:array[ :literal<x>, :literal<yy> ]),
     (my uint8 @ = [10, 20, 30]) => (:array[ :int(10), :int(20), :int(30) ]),
     %( :a(10), :b[1, 2.1, 'x', ], :c(:name<x>) ) => (:dict{ :a(:int(10)), :b(:array($[:int(1), :real(2.1), :literal("x")])), :c(:name("x")) }),
      [ True, False, Any, {}, ] => (:array[ :bool, :!bool, :null(Any), :dict{} ]),
  ) {
    my $v = .key;
    my $a = .value;
    my $ast = to-ast($v);
    is-deeply $ast, $a, "to ast {$v.perl}";
}
