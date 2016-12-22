use v6;
use Test;

use PDF;
use PDF::Reader;

for 't/pdf/samples'.IO.dir.sort -> \pdf-file {

    my Str \ext = pdf-file.extension;
    next unless ext ~~ m:i/ [json|pdf|fdf] $/;
    my $desc = ~ pdf-file;

    my $pdf;
    if $desc ~~ /damaged/ {
        dies-ok {$pdf = PDF.open( pdf-file ); $pdf.Info}, "$desc open - dies";
        next;
    }

    lives-ok {$pdf = PDF.open( pdf-file ); $pdf.Info}, "$desc open - lives"
        or next;

    isa-ok $pdf, ::('PDF'), "$desc trailer";
    ok $pdf.reader.defined, "$desc \$pdf.reader defined";
    isa-ok $pdf.reader, ::('PDF::Reader'), "$desc reader type";

    ok $pdf<Root>, "$desc document has a root";
    isa-ok $pdf<Root>, ::('PDF::DAO::Dict'), "$desc document root";

    if ext eq 'fdf' {
	ok $pdf<Root> && $pdf<Root><FDF>, "$desc <Root><FDF> entry";
    }
    else {
	ok $pdf<Root> && $pdf<Root><Pages>, "$desc <Root><Pages> entry";

	unless pdf-file ~~ /'no-pages'/ {
	    does-ok $pdf.Info, ::('PDF::DAO::Type::Info'), "$desc document info";
	    ok $pdf.Info && $pdf.Info.CreationDate // $pdf.Info.ModDate, "$desc <Info><CreationDate> entry";
	    isa-ok $pdf<Info><CreationDate>//$pdf<Info><ModDate>, DateTime, "$desc CreationDate";
        }
    }

}

done-testing;
