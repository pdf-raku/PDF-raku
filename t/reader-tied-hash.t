use v6;
use PDF::Reader::Tied::Hash;
use Test;

my $h = {
    :A(10),
    :Kids[
         42,
         { :X(99) }
        ],
} but PDF::Reader::Tied::Hash;

is $h<A>, 10, 'shallow reference';
lives_ok {++$h<A>}, 'shallow reference preincrement';
is_deeply $h<Kids>[0], (42), 'deep reference';
is $h<Kids>[1]<X>, 99, 'deep reference';
lives_ok {$h<Kids>[1]<X>++;}, 'deep post increment';
is $h<Kids>[1]<X>, 100, 'incremented';

done;

