use v6;
use PDF::Object;
use PDF::Object::Dict;
use PDF::Object::Array;
use PDF::Storage::IndObj;
use PDF::Grammar::Test :is-json-equiv;
use Test;

our %ties;
our $dummy-reader;

class t::DummyReader {
    has %.object-cache;
    has Bool $.auto-deref is rw = True;
    method ind-obj($obj-num, $gen-num) {
        %ties{$obj-num}{$gen-num} //= do {
            my %dict = :Name<Test>,
            :Desc("indirect object: $obj-num $gen-num R");

            my $ind-obj = [$obj-num, $gen-num, :%dict];

            PDF::Storage::IndObj.new( :$ind-obj, :reader(self) );
        }
    }
}

my $reader = t::DummyReader.new;

my $obj = PDF::Object.compose(
    :dict{
        :A(10),
        :B(:ind-ref[42,5]),
        :Kids[
             42,
             { :X(99) },
             :ind-ref[99,0],
            ],
    },
    :$reader
    );

is $obj<A>, 10, 'shallow reference';
isa-ok $obj, PDF::Object::Dict;
is-deeply $obj<B>, {Desc => "indirect object: 42 5 R", :Name<Test>}, 'hash dereference';

my $raw;
lives-ok {$raw = $obj.clone}, '.clone - lives';
is-deeply $raw<B>, (:ind-ref[42, 5]), 'new hash entry - .clone deref';

isa-ok $obj<Kids>, PDF::Object::Array;
is-deeply $obj<Kids>.reader, $reader, 'reader array stickyness';
is-deeply $obj<Kids>[2], {Desc => "indirect object: 99 0 R", :Name<Test>}, 'array dereference';
$obj<B><SubRef> = :ind-ref[77, 0];
is-deeply $obj<B><SubRef>, {Desc => "indirect object: 77 0 R", :Name<Test>}, 'new hash entry - deref';
is-deeply $obj<B>.clone<SubRef>, (:ind-ref[77, 0]), 'new hash entry - clone';
lives-ok {++$obj<A>}, 'shallow reference preincrement';
is-deeply $obj<Kids>[0], (42), 'deep reference';
is-deeply $obj<Kids>[1].reader, $reader, 'deep reference stickyness';

is $obj<Kids>[1]<X>, 99, 'deep reference';
lives-ok {$obj<Kids>[1]<X>++;}, 'deep post increment';
is $obj<Kids>[1]<X>, 100, 'incremented';

lives-ok {$obj<Kids>[1]<Parent> = $obj}, 'circular assignment - lives';
my $parent;
lives-ok { $parent = $obj<Kids>[1]<Parent>}, 'circular deref - lives';
is ~$parent.WHICH, ~$obj.WHICH, 'assign/deref - graphical integrity';
$obj<Kids>.push( (:ind-ref[123,0]) );
is-deeply $obj<Kids>[3], {Desc => "indirect object: 123 0 R", :Name<Test>}, 'new array entry - deref';
is-deeply $obj<Kids>.clone[3], (:ind-ref[123, 0]), 'new array entry - clone';
lives-ok {$obj<Y><Z> = 'foo'}, 'vivification - lives';
is $obj<Y><Z>, 'foo', 'vivification - value';
isa-ok $obj<Y>, PDF::Object::Dict, 'vivification - type';
is-deeply $obj<Y>.reader, $reader, 'vivification - reader stickyness';
# other abstracted methods
$obj<Kids>[4] = $obj<B><SubRef>;
$obj<Kids>.push: [1,2,3];
is +$obj<Kids>, 6, '+$obj<Kids>';
isa-ok $obj<Kids>[*-1], PDF::Object::Array, 'push coercian';
$obj<Kids>.splice(1,4, {:Foo<bar>});
is +$obj<Kids>, 3, '+$obj<Kids>';
isa-ok $obj<Kids>[1], PDF::Object::Dict, 'splice coercian';
$obj<Kids>.unshift([99]);
isa-ok $obj<Kids>[0], PDF::Object::Array, 'unshift coercian';

lives-ok {$obj<Kids>[4] = {}}, 'bind-pos array';
my $x = 'before';
lives-ok {$obj<Kids>[4]<Bound> := $x}, 'bind-pos hash';
$x = 'after';
is $obj<Kids>[4]<Bound>, 'after', 'hash really is bound';
is-deeply $obj<Kids>[4].reader, $reader, 'reader bind-array/pos stickyness';

is-json-equiv $obj<Kids>.clone, [[99], 42, {:Foo<bar>}, [1, 2, 3], { :Bound<after> } ], 'final';

done;
