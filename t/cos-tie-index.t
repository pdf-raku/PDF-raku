use v6;
use Test;
plan 8;

use PDF::COS::Array;

{
    # basic tests
    my role MyRole {};
    class TestArray
    is PDF::COS::Array {
        use PDF::COS::Tie;
        has Int $.I0 is index(0, :required);
        multi sub coerce($v, MyRole) { $v does MyRole }
        has MyRole $.R1 is index(1, :&coerce);
        has Int %.H2 is index(2);
        has Int $.I3 is index(3, :required);
    }

    my $array-in = [42, 10, { :a(20), :b(30) }, 40 ];
    my $array;
    lives-ok { $array = TestArray.new: :array($array-in) }, 'construction sanity';
    isa-ok $array, Array;
    is $array.I0, 42, 'accessor sanity';
    is $array.R1, 10, 'coercement';
    does-ok $array.R1, MyRole, 'coercement';
    is $array.H2<b>, 30, 'container';
    $array.pop;
    $array.pop;
    lives-ok {$array.H2}, 'non-required field';
    dies-ok {$array.I3},  'required field';
}


done-testing;
