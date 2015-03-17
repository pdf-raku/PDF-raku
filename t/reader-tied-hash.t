use v6;
use PDF::Reader::Tied;
use Test;

our %ties;
our $dummy-reader;

class t::DummyReader {
    method tied($obj-num, $gen-num) {
        %ties{$obj-num}{$gen-num} //= do {
            my %a = :Type<Test>,
            :Desc("tie to: $obj-num $gen-num R");

            my $t = %a but PDF::Reader::Tied;
            $t.reader = $dummy-reader;
            $t;
        }
    }
}

$dummy-reader = t::DummyReader.new;

my $h = {
    :A(10),
    :B(:ind-ref[42,5]),
    :Kids[
         42,
         { :X(99) },
         :ind-ref[99,0],
        ],
} but PDF::Reader::Tied;

$h.reader = $dummy-reader;

is $h<A>, 10, 'shallow reference';
is_deeply $h<B>, {Desc => "tie to: 42 5 R", :Type("Test")}, 'hash dereference';
is_deeply $h<Kids>[2], {Desc => "tie to: 99 0 R", :Type("Test")}, 'array dereference';
$h<B><SubRef> = :ind-ref[77, 0];
is_deeply $h<B><SubRef>, {Desc => "tie to: 77 0 R", :Type("Test")}, 'new hash entry';
lives_ok {++$h<A>}, 'shallow reference preincrement';
is_deeply $h<Kids>[0], (42), 'deep reference';
is $h<Kids>[1]<X>, 99, 'deep reference';
lives_ok {$h<Kids>[1]<X>++;}, 'deep post increment';
is $h<Kids>[1]<X>, 100, 'incremented';
$h<Kids>.push( (:ind-ref[123,0]) );
is_deeply $h<Kids>[3], {Desc => "tie to: 123 0 R", :Type("Test")}, 'new array entry';

done;

