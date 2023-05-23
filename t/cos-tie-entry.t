use v6;
use Test;
plan 76;

use PDF::COS::Dict;
use PDF::COS::Name;
use PDF::COS::TextString;
use PDF::Grammar::Test :is-json-equiv;

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
        has PDF::COS::Name $.Name is entry(:default<Foo>);
        has PDF::COS::Name @.Names is entry(:default['a', 'b', 'c']);
        has PDF::COS::TextString $.Txt is entry;
        subset NameX of PDF::COS::Name where 'X';
        has NameX $.X is entry;
    }

    my TestDict $dict;

    lives-ok { $dict .= new( :dict{ :IntReq(42) } ) }, 'dict sanity';
    is $dict.keys, <IntReq>, '.keys';
    is $dict.IntReq, 42, "dict accessor sanity";
    is $dict.required-int, 42, "dict alias accessor";

    lives-ok { $dict .= new( :dict{ :required-int(42) } ) }, 'dict construction from alias';
    is $dict.keys, <IntReq>, 'from alias .keys';
    is $dict.IntReq, 42, "from alias accessor";
    is $dict.required-int, 42, "from alias, alias accessor";

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
    is-deeply $dict.Txt, PDF::COS::TextString, 'entry without default';
    lives-ok {$dict.Txt = PDF::COS::TextString}, 'assignment to correct type object';
    quietly dies-ok {$dict.Txt = Hash}, 'assigment to wrong type object';
    is-deeply $dict.Txt, PDF::COS::TextString, 'entry without default';
    ok !($dict<Name>:exists), 'defaulted entry';
    ok !($dict<Name>.defined), 'defaulted raw value';
    is $dict.Name, 'Foo', 'defaulted accessor value';
    does-ok $dict.Name, PDF::COS::Name, 'defaulted type';
    ok !($dict<Name>:exists), 'defaulted entry';
    $dict.Name = 'Bar';
    ok ($dict<Name>:exists), 'default value assignment';
    is $dict.Name, 'Bar', 'default value assignment';
    does-ok $dict.Name, PDF::COS::Name;

    enum « :Baz<baz> »;
    lives-ok {$dict.Name = Baz}, 'String enum assigment';
    is $dict.Name, 'baz', 'default value assignment';
    does-ok $dict.Name, PDF::COS::Name;

    is $dict.Names[1], 'b', 'defaulted array';
    does-ok $dict.Names[1], PDF::COS::Name, 'defaulted array';
    lives-ok { $dict.Txt = 'Hi';}, 'text-string sanity';
    lives-ok { $dict.X = 'X';}, 'name subset valide';
    dies-ok { $dict.X = 'Y';}, 'name subset invalid';
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
    todo "typecheck on array elements";
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

    # defaults on containers
    $dict .= new: :dict{};
    does-ok $dict.I, Positional;
    does-ok $dict.Neg, Associative;
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


{
    # role mixin tests
    use PDF::COS::Dict;
    use PDF::COS::Tie;
    use PDF::COS::Tie::Array;
    my enum Fit « :FitXYZoom<XYZ>  :FitWindow<Fit> :FitZoom<Zoom> »;
    role DestArray
        does PDF::COS::Tie::Array {
        has $.page is index(0);
        has PDF::COS::Name $.fit is index(1);
    }
    role DestDict does PDF::COS::Tie::Hash {
        has DestArray $.D is entry(:required, :alias<destination>);
    }
    class Catalog
        is PDF::COS::Dict {
        use PDF::COS::Tie;

        my subset Dest where DestDict|DestArray;

        multi sub coerce(Hash $dict, Dest) {
            DestDict.COERCE($dict);
        }
        multi sub coerce(List $array, Dest) {
            DestArray.COERCE($array);
        }
        multi sub coerce($_, Dest) is default {
            fail "unable to coerce to a destination: {.perl}";
        }
        has Dest %.Dests is entry(:&coerce);
    }

    my %Dests = %( :A[1, 'XYZ'],
                   :B{ :D[2, FitZoom] },
                   :C{ :destination[3, 'Fit'] },  # alias
                 );
    my Catalog $Catalog .= new: :dict{ :%Dests };
    is-json-equiv $Catalog, {:Dests{ :A[1, "XYZ"], :B{ :D[2, "Zoom"] }, :C{ :D[3, "Fit"] } }}, 'mixin';
    does-ok $Catalog.Dests<B>.D.page, 2, 'mixin';
}
  
done-testing;
