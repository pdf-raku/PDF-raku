use v6;
use Test;

use PDF::DAO::Doc;
use PDF::DAO::Type::Info;

for 't/pdf/samples'.IO.dir.sort {

    my Str $pdf-filename = ~$_;
    my Str $ext = $pdf-filename.IO.extension;
    next unless $ext ~~ m:i/ [json|pdf|fdf] $/;

    for False, True -> Bool $repair {
	my $desc = "$pdf-filename {:$repair.perl}";
	my $doc;
	lives-ok {$doc = PDF::DAO::Doc.open( $pdf-filename, :$repair ); }, "$desc open - lives";

	isa-ok $doc, PDF::DAO::Doc, "$desc trailer";
	ok $doc.reader.defined, "$desc \$doc.reader defined";
	isa-ok $doc.reader, ::('PDF::Reader'), "$desc reader type";

	ok $doc<Root>, "$desc document has a root";
        isa-ok $doc<Root>, ::('PDF::DAO::Dict'), "$desc document root";

	if $ext eq 'fdf' {
	    ok $doc<Root> && $doc<Root><FDF>, "$desc <Root><FDF> entry";
	}
	else {
	    ok $doc<Root> && $doc<Root><Pages>, "$desc <Root><Pages> entry";

	    unless $pdf-filename ~~ /'no-pages'/ {
	        does-ok $doc.Info, PDF::DAO::Type::Info, "$desc document info";
	        ok $doc.Info && $doc.Info.CreationDate, "$desc <Info><CreationDate> entry";
	        isa-ok $doc<Info><CreationDate>, DateTime, "$desc CreationDate";
            }
        }
    }

}

done-testing;
