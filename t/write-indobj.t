use v6;
use Test;
plan 1;

use PDF::IO::IndObj;
use PDF::Writer;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my PDF::Grammar::PDF::Actions $actions .= new;

my $input = 't/pdf/ind-obj.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;

my PDF::IO::IndObj $ind-obj .= new( :$input, |%ast );
my PDF::Writer $pdf-out .= new( :$input );

# round trip
$input = $pdf-out.write( $ind-obj.ast );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "reparse failed";
%ast = $/.ast;

my PDF::IO::IndObj $ind-obj2 .= new( :$input, |%ast );

is-deeply $ind-obj.object.decoded, $ind-obj2.object.decoded, 'writer round trip';
