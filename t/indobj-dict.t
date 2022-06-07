use v6;
use Test;
plan 29;

use PDF::IO::IndObj;
use PDF::COS::Util :to-ast;
use PDF::COS::Dict;
use PDF::Grammar::Test :is-json-equiv;

my $reader = class {
    has Bool $.auto-deref = False
}.new;

sub ind-obj-tests( :$ind-obj!, :$class!, :$to-json) {
    my PDF::IO::IndObj $dict-obj .= new( :$ind-obj, :$reader );
    my $object = $dict-obj.object;
    isa-ok $object, $class;
    is-deeply $object.reader, $reader, 'reader stickeyness';
    is $dict-obj.obj-num, $ind-obj[0], '$.obj-num';
    is $dict-obj.gen-num, $ind-obj[1], '$.gen-num';
    is-json-equiv $dict-obj.object, $to-json, 'object to json';
    my $content = $dict-obj.content;
    is-json-equiv $dict-obj.ast, (:$ind-obj), 'ast regeneration';
}

ind-obj-tests(
    :ind-obj[ 21, 0, :dict{ D => :array[ :ind-ref[216, 0], :name<XYZ>, 0, 441, Any],
                            S => :name<GoTo>}],
    :class(PDF::COS::Dict),
    :to-json{ :D[ :ind-ref[216, 0], "XYZ", 0, 441, Any], :S<GoTo> },
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
    :class(PDF::COS::Dict),
    :to-json{ :P{ :ind-ref[ 142, 0 ] },
              :S<Link>,
              :K[ :ind-ref[ 207, 0 ],
                  { :Type<OBJR>,
                    :Pg{ :ind-ref[ 216, 0 ] },
                    :Obj{ :ind-ref[ 233, 0 ] },
                  }
                  ] },
    );

use PDF::COS::Tie;
use PDF::COS::Tie::Hash;
use PDF::COS::Dict;
role ResourceRole does PDF::COS::Tie::Hash {method foo {42}}
role KidRole does PDF::COS::Tie::Hash {method bar {42}}
role MyPages does PDF::COS::Tie::Hash {
    multi sub coerce(Hash $h is rw, KidRole) { $h does KidRole }
    multi sub coerce(Hash $h is rw, ResourceRole) { $h does ResourceRole }
    has KidRole @.Kids is entry(:required, :indirect, :&coerce );
    has ResourceRole %.Resources is entry( :&coerce );
}

class MyCat
    is PDF::COS::Dict {
    has MyPages $.Pages is entry(:required, :indirect);
    has Bool $.NeedsRendering is entry;
}

my MyCat $cat .= new( :dict{ :Pages{ :Kids[ { :Type( :name<Page> ) }, ], :Resources{ :ExtGState{} }, } } );

isa-ok $cat, MyCat, 'root object';
does-ok $cat<Pages>, MyPages, '<Pages> role';
does-ok $cat.Pages, MyPages, '.Pages role';

isa-ok $cat<Pages><Kids>, Array, '<Pages><Kids>';
is-json-equiv $cat<Pages><Kids>, [ { :Type<Page> }, ], '<Pages><Kids>';
isa-ok $cat.Pages.Kids, Array, '.Pages.Kids';
is-json-equiv $cat.Pages.Kids, [{ :Type<Page> }, ], '.Pages.Kids';

isa-ok $cat<Pages><Resources>, Hash, '<Pages><Resources>';
does-ok $cat.Pages.Resources<ExtGState>, ResourceRole, 'Hash Instance role';

lives-ok { $cat.NeedsRendering = True }, 'valid assignment';
quietly {
    dies-ok { $cat.NeedsRendering = 42 }, 'typechecking';
}
is-json-equiv $cat.NeedsRendering, True, 'typechecking';
is $cat.Pages.Kids[0]<Type>, 'Page', '.Pages.Kids[0]<Type>';
does-ok $cat.Pages.Kids[0], KidRole, 'Array Instance role';
is $cat.Pages.Kids[0].obj-num, -1, '@ sigil entry(:indirect)';
dies-ok {$cat.Pages.Kids[1] = 42}, 'typechecking - array elems';

use PDF;
use PDF::IO::Serializer;
my %dict = :Root($cat);
my PDF $pdf .= new( :%dict );
my PDF::IO::Serializer $serializer .= new;
my $body = $serializer.body( $pdf );

is-json-equiv $body[0], {
    :objects[
	     :ind-obj($[1, 0, :dict{ :NeedsRendering,
				     :Pages(:ind-ref($[2, 0]))}
                       ]),
             :ind-obj($[2, 0, :dict{ :Kids(:array($[:ind-ref($[3, 0])])),
                                     :Resources{ :dict{ :ExtGState{ :dict{} } } },
                                   }]),
             :ind-obj($[3, 0, :dict{ :Type(:name("Page"))}])
         ],
    :trailer{ :dict{:Root(:ind-ref($[1, 0])), :Size(4)}} 
}, 'body serialization';
