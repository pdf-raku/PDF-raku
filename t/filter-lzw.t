use Test;

plan 2;

use PDF::IO::Filter;
use PDF::IO::Filter::LZW;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::IO;
use PDF::IO::IndObj;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-LZW.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;

my $expected = "q\r600 0 0 845 0 0 cm\r/Im0 Do\rQ";

my $pdf-input = PDF::IO.coerce( $input );
my $ind-obj = PDF::IO::IndObj.new( :$input, |%ast );
my $dict = $ind-obj.object;
my $raw-content = $pdf-input.stream-data( |%ast )[0];
my $content;

lives-ok {$content = PDF::IO::Filter.decode( $raw-content, :$dict ); }, 'basic content decode - lives';
is-deeply $content.decode("latin-1"), $expected, 'LZW Decompression';
