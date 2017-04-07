use v6;
use Test;
plan 8;

use PDF::IO::IndObj;
use PDF::IO::Util;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

diag "*** NOTE installing Lib::PDF will speed up this test ***"
    unless PDF::IO::Util::libpdf-available;

for <xt/pdf/png-pred-4bpc.in xt/pdf/png-pred-16bpc.in xt/pdf/png-pred-1bpc.in xt/pdf/png-pred-4bpc-odd-col-count.in> {
    my $input = .IO.slurp( :enc<latin-1> );
    my $p = PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
        // die "parse of $_ failed";
    my %ast = $p.ast;

    my $ind-obj = PDF::IO::IndObj.new( :$input, |%ast );
    my $object = $ind-obj.object;

    my $decoded;
    quietly {
        lives-ok { $decoded = $object.decode }, "decode of $_";
        lives-ok { $object.encode($decoded) }, "encode of $_";
    }
    
}

done-testing;
