use v6;
use Test;

use PDF::Object::Doc;
use PDF::Object::Type::Info;

for 'sample-pdfs'.IO.dir.list {

    my Str $pdf-filename = ~$_;
    next unless $pdf-filename ~~ m:i/ '.' [json|pdf ] $/;

    for False, True -> Bool $repair {
	my $desc = "$pdf-filename {:$repair.perl}";
	my $doc;
	lives-ok {$doc = PDF::Object::Doc.open( $pdf-filename, :$repair ); }, "$desc open - lives";

	isa-ok $doc, PDF::Object::Doc, "$desc - trailer";
	ok $doc.reader.defined, '$doc.reader defined';
	isa-ok $doc.reader, ::('PDF::Reader'), '$doc.reader type';

	ok $doc<Root>, '$desc document has a root';
        isa-ok $doc<Root>, ::('PDF::Object::Dict'), "$desc document root";
	ok $doc<Root> && $doc<Root><Pages>, "$desc <Root><Pages> entry";

        does-ok $doc.Info, PDF::Object::Type::Info, "$desc document info";
        ok $doc.Info && $doc.Info.CreationDate, "$desc <Info><CreationDate> entry";
        isa-ok $doc<Info><CreationDate>, DateTime, '$desc CreationDate';
    }

}

done-testing;
