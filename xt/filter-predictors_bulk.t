use v6;
use Test;
plan 1;

use PDF::IO::IndObj;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 'xt/pdf/png-pred-4bpc.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;

my $ind-obj = PDF::IO::IndObj.new( :$input, |%ast );
my $object = $ind-obj.object;

my $decoded;
todo("PNG predictors with BPC < 8";
lives-ok { $decoded = $object.decode };

done-testing;
