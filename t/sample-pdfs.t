use v6;
use Test;

use PDF::DAO::Type::PDF;
use PDF::DAO::Type::Info;
use PDF::Storage::Crypt;

for 't/pdf/samples'.IO.dir.sort {

    my Str $pdf-filename = ~$_;
    my Str $ext = $pdf-filename.IO.extension;
    next unless $ext ~~ m:i/ [json|pdf|fdf] $/;

    for False, True -> Bool $repair {
	my $desc = "$pdf-filename {:$repair.perl}";
	my $pdf;
	lives-ok {$pdf = PDF::DAO::Type::PDF.open( $pdf-filename, :$repair ); $pdf.Info}, "$desc open - lives"
            or next;

	isa-ok $pdf, PDF::DAO::Type::PDF, "$desc trailer";
	ok $pdf.reader.defined, "$desc \$pdf.reader defined";
	isa-ok $pdf.reader, ::('PDF::Reader'), "$desc reader type";

	ok $pdf<Root>, "$desc document has a root";
        isa-ok $pdf<Root>, ::('PDF::DAO::Dict'), "$desc document root";

	if $ext eq 'fdf' {
	    ok $pdf<Root> && $pdf<Root><FDF>, "$desc <Root><FDF> entry";
	}
	else {
	    ok $pdf<Root> && $pdf<Root><Pages>, "$desc <Root><Pages> entry";

	    unless $pdf-filename ~~ /'no-pages'/ {
	        does-ok $pdf.Info, PDF::DAO::Type::Info, "$desc document info";
	        ok $pdf.Info && $pdf.Info.CreationDate // $pdf.Info.ModDate, "$desc <Info><CreationDate> entry";
	        isa-ok $pdf<Info><CreationDate>//$pdf<Info><ModDate>, DateTime, "$desc CreationDate";
            }
        }
    }

}

done-testing;
