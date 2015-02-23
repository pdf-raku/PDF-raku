use v6;
use Test;

plan 6;

use PDF::Tools::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-ObjStm-Flate.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;

my $ind-obj = PDF::Tools::IndObj.new-delegate( :$input, |%( $ast.kv ) );
isa_ok $ind-obj, ::('PDF::Tools::IndObj')::('Stream');
isa_ok $ind-obj.dict, Hash, '$.dict';
is_deeply $ind-obj.Length, (:int(167)), '$.Length';
is_deeply $ind-obj.Type, (:name<ObjStm>), '$.Type';
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
