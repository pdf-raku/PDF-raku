use v6;
use Test;

plan 22;

use PDF::Storage::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Reader;
use PDF::DOM::Page;

my $actions = PDF::Grammar::PDF::Actions.new;

my $input = q:to"--END-OBJ--";
3 0 obj
<<
  /Type /Pages
  /Count 2
  /Kids [4 0 R  5 0 R]
>>
endobj
--END-OBJ--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed";
my $ast = $/.ast;
my $ind-obj = PDF::Storage::IndObj.new( |%$ast);
is $ind-obj.obj-num, 3, '$.obj-num';
is $ind-obj.gen-num, 0, '$.gen-num';
my $pages-obj = $ind-obj.object;
isa-ok $pages-obj, ::('PDF::DOM')::('Pages');
is $pages-obj.Type, 'Pages', '$.Type accessor';
is $pages-obj.Count, 2, '$.Count accessor';
is-json-equiv $pages-obj.Kids, [ :ind-ref[4, 0], :ind-ref[5, 0] ], '$.Kids accessor';
is-json-equiv $pages-obj[0], (:ind-ref[4, 0]), '$pages[0] accessor';
is-json-equiv $pages-obj[1], (:ind-ref[5, 0]), '$pages[1] accessor';
is-deeply $ind-obj.ast, $ast, 'ast regeneration';

my $fdf-input = 't/pdf/fdf-PageTree.in';
my $reader = PDF::Reader.new( );
$reader.open( $fdf-input );
my $pages = $reader.root.object;

is $pages.Count, 62, 'number of pages';
is $pages[0].obj-num, 3, 'first page';
is $pages[0].find-prop('Rotate'), 180, 'inheritance';

is $pages[1].find-prop('Rotate'), 90, 'inheritance';

is $pages[5].obj-num, 37, 'sixth page';

is $pages[6].obj-num, 42, 'seventh page';

is $pages[60].obj-num, 324, 'second-last page';

is $pages[61].obj-num, 330, 'last page';
is $pages[61].find-prop('Rotate'), 270, 'inheritance';

my $new-page;
lives-ok {$new-page = $pages.add-page}, 'add-page - lives';
isa-ok $new-page, PDF::DOM::Page;
is $pages.Count, 63, 'number of pages';
is $pages[62].find-prop('Rotate'), 270, 'new page - inheritance';
