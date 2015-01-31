use Test;

plan 4;

use PDF::Core::Filter;
use PDF::Core::Filter::LZW;

use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Core;
use PDF::Core::Util :unbox;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = 't/pdf/ind-obj-A85+LZW.in'.IO.slurp( :enc<latin-1> );
PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;

my $pdf = PDF::Core.new( :$input );

my $dict = unbox( |%$ast )<dict>;
my $raw-content = $pdf.stream-data( |%$ast )[0];
my $content;

lives_ok { $content = PDF::Core::Filter.decode( $raw-content, :$dict ) }, 'basic content decode - lives';

my $raw-content2;
lives_ok { $raw-content2 = PDF::Core::Filter.encode( $content, :$dict ) }, 'basic content decode - lives';

my $content2;
lives_ok { $content2 = PDF::Core::Filter.decode( $raw-content2, :$dict ) }, 'basic content decode - lives';

is_deeply $content, $content2,
    q{basic LZW decompression - round trip};

