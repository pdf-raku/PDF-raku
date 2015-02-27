use v6;
use Test;

plan 11;

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

# crosschecks on /Type
require ::('PDF::Tools::IndObj::Type::Catalog');
my $dict = { :Pages(:ind-ref[3, 0]), :Outlines(:ind-ref[2, 0]), :Type(:name<Catalog>) };
my $catalog-obj = ::('PDF::Tools::IndObj::Type::Catalog').new( :$dict );
isa_ok $catalog-obj, ::('PDF::Tools::IndObj::Type::Catalog');
is_deeply $catalog-obj.Type, (:name<Catalog>), 'catalog $.Type';

$dict<Type>:delete;
lives_ok {$catalog-obj = ::('PDF::Tools::IndObj::Type::Catalog').new( :$dict )}, 'catalog .new with valid /Type - lives';
is_deeply $catalog-obj.Type, (:name<Catalog>), 'catalog $.Type (tied)';

$dict<Type> = :name<Wtf>;
dies_ok {::('PDF::Tools::IndObj::Type::Catalog').new( :$dict )}, 'catalog .new with invalid /Type - dies';
