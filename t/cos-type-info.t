use v6;
use Test;
plan 10;

use PDF::COS::Dict;
use PDF::COS::Name;
use PDF::COS::Type::Info;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my PDF::Grammar::PDF::Actions $actions .= new;

class DummyCatalog
    is PDF::COS::Dict {

    use PDF::COS::Tie;

    has PDF::COS::Type::Info $.Info is entry;
}

my $input = q:to"--ENOUGH!!--";
<< /Info <<
       /Title (PostScript Language Reference, Third Edition)
       /Author (Adobe Systems Incorporated)
       /Creator (Adobe FrameMaker 5.5.3 for Power Macintosh®)
       /Producer (Acrobat Distiller 3.01 for Power Macintosh)
       /CreationDate (D:19970915110347-08'00')
       /ModDate (D:19990209153925-08'00')
    >>
>>
--ENOUGH!!--

PDF::Grammar::PDF.parse($input, :$actions, :rule<object>)
    // die "parse failed";
my %dict = $/.ast.value;

my DummyCatalog $catalog .= new( :%dict );
isa-ok $catalog, DummyCatalog, 'catalog sanity';
isa-ok $catalog.Info, PDF::COS::Dict;
does-ok $catalog.Info, PDF::COS::Type::Info;
isa-ok $catalog.Info.CreationDate, DateTime, 'Info.CreationDate';
is $catalog.Info.CreationDate.year, 1997, 'Info.CreationDate.year';
is ~ $catalog.Info.CreationDate, "D:19970915110347-08'00'", 'Info.CreationDate stringification';
isa-ok $catalog.Info.Title, ::('PDF::COS::TextString'), 'Info.Title';
is $catalog.Info.Title, "PostScript Language Reference, Third Edition", 'Info.Title';
does-ok $catalog.Info.Trapped, PDF::COS::Name, 'Info.Trapped';
lives-ok {$catalog.check}, '.check lives';
