use Test;

plan 4;

use PDF::Storage::Filter;
use PDF::Storage::Filter::LZW;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Storage::Input;
use PDF::Storage::IndObj;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-A85+LZW.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my %ast = $/.ast;

my $pdf-input = PDF::Storage::Input.coerce( $input );
my $ind-obj = PDF::Storage::IndObj.new( :$input, |%ast );
my $dict = $ind-obj.object;
my $raw-content = $pdf-input.stream-data( |%ast )[0];
my $content;

lives-ok { $content = PDF::Storage::Filter.decode( $raw-content, :$dict ) }, 'basic content decode - lives';

my $raw-content2;
lives-ok { $raw-content2 = PDF::Storage::Filter.encode( $content, :$dict ) }, 'basic content decode - lives';

my $content2;
lives-ok { $content2 = PDF::Storage::Filter.decode( $raw-content2, :$dict ) }, 'basic content decode - lives';

is-deeply $content, $content2,
    q{basic LZW decompression - round trip};

