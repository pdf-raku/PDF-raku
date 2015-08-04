use v6;
use Test;

use PDF::Object;
use PDF::Storage::Serializer;
use PDF::Writer;

sub prefix:</>($name){ PDF::Object.coerce(:$name) };

my $doc-root = PDF::Object.coerce: { :Type(/'Catalog') };
my $outlines = PDF::Object.coerce: { :Type(/'Outlines'), :Count(0) };
$doc-root<Outlines> = $outlines;

my $pages = PDF::Object.coerce: { :Type(/'Pages') };
$doc-root<Pages> = $pages;

my $page = PDF::Object.coerce: { :Type(/'Page'), :MediaBox[0, 0, 420, 595] };
$pages<Kids> = [ $page ];
$pages<Count> = + $pages<Kids>;

my $font = PDF::Object.coerce: {
        :Type(/'Font'),
        :Subtype(/'Type1'),
        :Name(/'F1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    };

$page<Resources> = { :Font{ :F1($font) }, :Procset[ /'PDF', /'Text'] };

my $contents = PDF::Object.coerce( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) } );
$page<Contents> = $contents;
$page<Parent> = $pages;

my $body = PDF::Storage::Serializer.new.body($doc-root);
my $root = $body<trailer><dict><Root>;

my $ast = :pdf{ :version(1.2), :$body };

my $writer = PDF::Writer.new( :$root );
ok 't/helloworld.pdf'.IO.spurt( $writer.write( $ast ), :enc<latin-1> ), 'hello world';
done;
