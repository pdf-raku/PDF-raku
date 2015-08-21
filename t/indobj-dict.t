use v6;
use Test;

plan 23;

use PDF::Storage::IndObj;
use PDF::Object::Util :to-ast;
use PDF::Object::Dict;
use PDF::Grammar::Test :is-json-equiv;
use lib '.';
use t::Object :to-obj;

sub ind-obj-tests( :$ind-obj!, :$class!, :$to-obj!) {
    my $dict-obj = PDF::Storage::IndObj.new( :$ind-obj );
    my $object = $dict-obj.object;
    isa-ok $object, $class;
    is $dict-obj.obj-num, $ind-obj[0], '$.obj-num';
    is $dict-obj.gen-num, $ind-obj[1], '$.gen-num';
    my $content = $dict-obj.content;
    isa-ok $content, Pair;
    isa-ok to-obj( $content ), Hash, '$.content to-obj';
    is-json-equiv to-obj( $content ), $to-obj, '$.content to-obj';
    is-json-equiv $dict-obj.ast, (:$ind-obj), 'ast regeneration';
}

ind-obj-tests(
    :ind-obj[ 21, 0, :dict{ D => :array[ :ind-ref[216, 0], :name<XYZ>, :int(0), :int(441), :null(Any)],
                            S => :name<GoTo>}],
    :class(PDF::Object::Dict),
    :to-obj{ :D[ :ind-ref[216, 0], "XYZ", 0, 441, Any], :S<GoTo> },
    );

ind-obj-tests(
    :ind-obj[29, 0, :dict{ P => :ind-ref[142, 0],
                           S => :name<Link>,
                           K => :array[ :ind-ref[207, 0],
                                        :dict{Type => :name<OBJR>,
                                              Pg => :ind-ref[216, 0],
                                              Obj => :ind-ref[233, 0]},
                               ]},
    ],
    :class(PDF::Object::Dict),
    :to-obj{ :P{ :ind-ref[ 142, 0 ] },
              :S<Link>,
              :K[ :ind-ref[ 207, 0 ],
                  { :Type<OBJR>,
                    :Pg{ :ind-ref[ 216, 0 ] },
                    :Obj{ :ind-ref[ 233, 0 ] },
                  }
                  ] },
    );

use PDF::Object::Tie;
use PDF::Object::Tie::Hash;
use PDF::Object::Tie::Array;
role KidRole does PDF::Object::Tie::Hash {method bar {42}}
role MyPages does PDF::Object::Tie::Hash {
    has Hash @.Kids is entry(:required, :indirect );
}

class MyCat
    is PDF::Object::Dict {
    has MyPages $.Pages is entry(:required, :indirect, :coerce);
    has Bool $.NeedsRendering is entry;
}

my $cat = MyCat.new: { :Pages{ :Kids[ { :Type( :name<Page> ) } ] } };

isa-ok $cat, MyCat, 'root object';
ok $cat.Pages ~~ MyPages, '.Pages role';
isa-ok $cat.Pages.Kids, Array, '.Pages.Kids';
lives-ok { $cat.NeedsRendering = True }, 'valid assignment';
dies-ok { $cat.NeedsRendering = 42 }, 'typechecking';
is-deeply $cat.NeedsRendering, True, 'typechecking';
is $cat.Pages.Kids[0]<Type>, 'Page', '.Pages.Kids[0]<Type>';
todo ':does and @ sigil on entry traits', 2;
ok $cat.Pages.Kids[0] ~~ KidRole, 'Array Instance role';
dies-ok {$cat.Pages.Kids[1] = 42}, 'typechecking - array elems';
