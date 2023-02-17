use v6;
use Test;

use PDF;
use PDF::IO::Reader;

for 't/pdf/samples'.IO.dir.sort -> $file {

    my Str \ext = $file.extension;
    next unless ext ~~ m:i/ [json|pdf|fdf] $/;
    my $desc = ~ $file;

    my PDF $pdf;
    if $desc ~~ /damaged/ {
        dies-ok {$pdf .= new: :$file; $pdf.Info}, "$desc open - dies";
        next;
    }

    lives-ok { $pdf .= new: :$file; $pdf.Info; }, "$desc open - lives"
        or next;

    isa-ok $pdf, ::('PDF'), "$desc trailer";
    ok $pdf.reader.defined, "$desc \$pdf.reader defined";
    isa-ok $pdf.reader, ::('PDF::IO::Reader'), "$desc reader type";

    ok $pdf<Root>, "$desc document has a root";
    isa-ok $pdf<Root>, ::('PDF::COS::Dict'), "$desc document root";

    if ext eq 'fdf' {
	ok $pdf<Root> && $pdf<Root><FDF>, "$desc <Root><FDF> entry";
    }
    else {
	ok $pdf<Root> && $pdf<Root><Pages>, "$desc <Root><Pages> entry";

	unless $file ~~ /'no-pages'/ {
	    does-ok $pdf.Info, ::('PDF::COS::Type::Info'), "$desc document info";
	    ok $pdf.Info && $pdf.Info.CreationDate // $pdf.Info.ModDate, "$desc <Info><CreationDate> entry";
	    isa-ok $pdf<Info><CreationDate>//$pdf<Info><ModDate>, DateTime, "$desc CreationDate";
        }
    }

}

done-testing;
