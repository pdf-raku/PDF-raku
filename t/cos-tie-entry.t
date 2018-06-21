use v6;
use Test;
plan 47;

use PDF::COS::Dict;

{
    # basic tests
    class TestDict
    is PDF::COS::Dict {
        use PDF::COS::Tie;
        has Int $.IntReq is entry(:required, :alias<required-int>);
        has Hash $.DictInd is entry(:indirect);
        subset FredDict of Hash where {.<Name> ~~ 'Fred'}
        has FredDict $.SubsetDict is entry;
        has UInt $.three-dd is entry(:key<3DD>);
    }

    my TestDict $dict;
    lives-ok { $dict .= new( :dict{ :IntReq(42) } ) }, 'dict sanity';
    is $dict.IntReq, 42, "dict accessor sanity";
    is $dict.required-int, 42, "dict alias accessor";
    lives-ok { $dict.IntReq = 43 }, 'dict accessor assignment sanity';
    quietly {
        dies-ok { $dict.IntReq = 'urrgh' }, 'dict accessor assignment typecheck';
        is $dict.IntReq, 43, 'dict accessor typecheck';
        lives-ok { $dict .= new( :dict{ :IntReq<oops> } ) }, 'dict typecheck bypass';
        dies-ok {$dict.check}, ".check on invalid dict";
        dies-ok {$dict.IntReq}, "dict accessor - typecheck";
        lives-ok {$dict.IntReq = 99}, "post-assigment to required field";
        lives-ok {$dict.check}, ".check on now valid dict";
        dies-ok { TestDict.new( :dict{ } ) }, 'dict without required - dies';
    }
    $dict .= new( :dict{ :IntReq(42), :DictInd{}, } );
    $dict.three-dd = 88;
    is $dict<3DD>, 88, ':key trait option';
    $dict."3DD"() = 99;
    is $dict."3DD"(), 99, ':key trait option';
    ok $dict.DictInd.is-indirect, 'indirect entry';
    my $fred = %( :Name<Fred> );
    ok $fred ~~ TestDict::FredDict, 'subset sanity';
    lives-ok {$dict.SubsetDict =  $fred;}, 'subset dict - valid';
    quietly dies-ok {$dict.SubsetDict =  %()}, 'subset dict - invalid';
}

{
    # container tests
    class TestDict2
    is PDF::COS::Dict {
        use PDF::COS::Tie;
        has UInt @.I is entry;
        has Str @.S is entry(:array-or-item);
        has UInt @.LenThree is entry(:len(3));
        has Int %.Neg is entry where * < 0;
    }

    my TestDict2 $dict;
    lives-ok { $dict .= new( :dict{ :I[3, 4], :S['xx'], :Neg{ :n1(-7),  :n2(-8) } } ) }, 'container sanity';
    is $dict.I[1], 4, 'array container deref sanity';
    is $dict.S[0], 'xx', 'array container deref sanity';
    lives-ok { $dict.I[1] = 5 }, 'array assignment sanity';
    lives-ok { $dict.S[1] = 'yy' }, 'array assignment sanity';
    my @s = $dict.S.List;
    is @s[1], 'yy', "array container assignment";
    todo "typecheck on array elements", 2;
    quietly dies-ok { $dict.I[1] = -5 }, 'array assignment typecheck';
    lives-ok { $dict.I[1] = 42 }, 'array assignment typecheck';

    $dict.S = 'singular';
    my $s;
    lives-ok {$s = $dict.S[0]}, 'fetch of singular value';
    is $s, 'singular', 'fetch of array-or-item';
    is $dict.S, 'singular', 'fetch of array-or-item';

    is $dict.Neg<n2>,-8, 'hash container deref sanity';
    lives-ok { $dict.Neg<n2> = -5 }, 'hash assignment sanity';
    todo "typecheck on hash elements";
    quietly dies-ok { $dict.Neg<n2> = 5 }, 'hash assignment typecheck';

    dies-ok { $dict.LenThree = [10, 20] }, 'length check, invalid';
    lives-ok { $dict.LenThree = [10, 20, 30] }, 'length check, valid';
}

{
    # coercement tests
    my role MyRole {};
    class TestDict3
        is PDF::COS::Dict {
        use PDF::COS::Tie;

        multi sub coerce($v, MyRole) { $v does MyRole }
        has MyRole $.Coerced is entry(:&coerce);
    }

    my TestDict3 $dict .= new( :dict{ :Coerced(42) } );
    is $dict.Coerced, 42, 'coercement';
    does-ok $dict.Coerced, MyRole, 'coercement';
}

{
    # inheritance tests
    class Node
        is PDF::COS::Dict {
        use PDF::COS::Tie;
        has PDF::COS::Dict $.Resources is entry(:inherit);
        has PDF::COS::Dict $.Parent is entry;
    }

    my Node $Parent .= new( :dict{ :Resources{ :got<parent> }  } );
    my Node $child-with-entry .= new( :dict{ :Resources{ :got<child> }, :$Parent, } );
    my Node $child-without-entry .= new( :dict{ :$Parent, } );
    my Node $orphan .= new( :dict{ } );
    my Node $two-deep .= new( :dict{ :Parent($child-without-entry) } );
    my Node $cyclical .= new( :dict{ } );
    $cyclical<Parent> = $cyclical;

    is $Parent.Resources<got>, 'parent', 'parent accessor';
    is $Parent<Resources><got>, 'parent', 'parent direct';

    is $child-with-entry.Resources<got>, 'child', 'child with';
    is $child-with-entry<Resources><got>, 'child', 'child with, direct';
    is $child-without-entry.Resources<got>, 'parent', 'child without';
    nok $child-without-entry<Resources>, 'child without, direct';
    nok $orphan.Resources, 'orphan';
    is $two-deep.Resources<got>, 'parent', 'child inheritance (2 levels)';

    $child-without-entry<Resources><got> = 'child';
    is $child-with-entry.Resources<got>, 'child', 'resources insertion, child';
    is $Parent.Resources<got>, 'parent', 'resources insertion, parent';

    dies-ok {$cyclical.Resources}, 'inheritance cycle detection';
}

done-testing;
