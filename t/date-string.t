use v6;
use Test;
use PDF::Object;
use PDF::Object::DateString;

my $date = PDF::Object::DateString.new("D:199812231952-08'00'");

is $date.year, 1998, 'Date year';
is $date.month, 12, 'Date month';
is $date.day, 23, 'Date day';
is $date.hour, 19, 'Date hour';
is $date.minute, 52, 'Date minute';
is $date.offset, -8*60*60, 'Date offset';

$date = PDF::Object::DateString.new("1999");
is $date.year, 1999, 'Date year';
is $date.month,   1, 'Date month (default)';
is $date.day,     1, 'Date day (default)';
is $date.hour,    0, 'Date hour (default)';
is $date.minute,  0, 'Date minute (default)';
is $date.offset,  0, 'Date offset (default)';

use PDF::Object::Dict;
class MyInfo is PDF::Object::Dict {
    use PDF::Object::Tie;
    has PDF::Object::DateString $.CreationDate is entry;
}

my $info = MyInfo.new( :dict{ :CreationDate( :literal<D:20130629204853+02'00'> ) } );

is $info.CreationDate, q<D:20130629204853+02'00'>, 'raw creation date';
my $creation-date = $info.CreationDate;
isa-ok $creation-date, DateTime;
is $creation-date.year, 2013, 'creation date year';
is $creation-date.offset, 2*60*60, 'creation date offset';
is ~$creation-date, q<D:20130629204853+02'00'>, 'creation data stringified';

is-deeply $creation-date.content, (:literal<D:20130629204853+02'00'>), 'creation date content';

lives-ok {$info.CreationDate = DateTime.new(:year(2105), :month(12), :day(25))}, "DateTime assignment - lives";
is-deeply $creation-date.content, (:literal<D:20130629204853+02'00'>), 'creation date content';

done-testing;
