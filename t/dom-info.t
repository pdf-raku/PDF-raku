use v6;
use Test;

plan 8;

use PDF::DAO::Dict;
use PDF::DAO::Type::Info;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;

my $actions = PDF::Grammar::PDF::Actions.new;

class DummyCatalog
    is PDF::DAO::Dict {

    use PDF::DAO::Tie;

    has PDF::DAO::Type::Info $.Info is entry;
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
my $ast = $/.ast;

my $catalog = DummyCatalog.new( $ast.value );
isa-ok $catalog, DummyCatalog, 'catalog sanity';
isa-ok $catalog.Info, PDF::DAO::Dict;
does-ok $catalog.Info, PDF::DAO::Type::Info;
isa-ok $catalog.Info.CreationDate, DateTime, 'Info.CreationDate';
is $catalog.Info.CreationDate.year, 1997, 'Info.CreationDate.year';
is ~ $catalog.Info.CreationDate, "D:19970915110347-08'00'", 'Info.CreationDate stringification';
isa-ok $catalog.Info.Title, ::('PDF::DAO::TextString'), 'Info.Title';
is $catalog.Info.Title, "PostScript Language Reference, Third Edition", 'Info.Title';
