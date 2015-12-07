use v6;
use Test;

plan 14;

use PDF::Storage::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::DAO::Stream;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-ObjStm-Flate.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed: $input";
my $ast = $/.ast;

my $ind-obj = PDF::Storage::IndObj.new( :$input, |%( $ast.kv ) );
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $object = $ind-obj.object;
isa-ok $object, ::('PDF::DAO::Stream');
isa-ok $object, Hash;
isa-ok $object.Length, Int, '$.Length';
is $object.Length, 167, '$.Length';
is $object.Type, 'ObjStm', '$.Type';

my $num-obj = PDF::DAO.coerce( :real(4.2) );
is-deeply $num-obj.content, (:real(4.2)), 'composed object $.content';
is +$num-obj, 4.2, 'composed object Num coercement';
is-deeply ~$num-obj, '4.2', 'composed object Str coercement';
is-deeply ?$num-obj, True, 'composed object Bool coercement';

my $ind-obj2 = PDF::Storage::IndObj.new( :object($num-obj), :obj-num(4), :gen-num(2) );
is-deeply $ind-obj2.object, $num-obj, ':object constructor';
is-deeply $ind-obj2.obj-num, 4, ':object constructor';
is-deeply $ind-obj2.gen-num, 2, ':object constructor';

