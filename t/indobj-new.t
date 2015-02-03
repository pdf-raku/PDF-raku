use v6;
use Test;

plan 6;

use PDF::Tools::IndObj;
use PDF::Tools::Writer;

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
is $ind-obj.dict<Length>.value, 167, '$.dict<Length>';
is $ind-obj.obj-num, 5, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';

my $pdf-out = PDF::Tools::Writer.new( :$input );

# round trip
$input = $pdf-out.write( $ind-obj );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "reparse failed";
$ast = $/.ast;

my $ind-obj2 = PDF::Tools::IndObj.new-delegate( :$input, |%( $ast.kv ) );

is_deeply $ind-obj.decoded, $ind-obj2.decoded, 'writer round trip';
