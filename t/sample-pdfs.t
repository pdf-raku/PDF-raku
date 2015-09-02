use v6;
use Test;

use PDF::Object::Doc;

for 'sample-pdfs'.IO.dir.list {

    my Str $pdf-filename = ~$_;
    next unless $pdf-filename ~~ m:i/ '.' [json|pdf ] $/;

    for False, True -> Bool $repair {
	my $desc = "$pdf-filename {:$repair.perl}";
	my $doc;
	lives-ok {$doc = PDF::Object::Doc.open( $pdf-filename, :$repair )}, "$desc open - lives";

	isa-ok $doc, PDF::Object::Doc, "$desc - trailer";

	ok $doc<Root>, 'document has a root';
	isa-ok $doc<Root>, ::('PDF::Object::Dict'), "$desc document root";
	ok $doc<Root> && $doc<Root><Pages>, "$desc <Root><Pages> entry";
    }

}

done;
