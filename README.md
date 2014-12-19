perl6-PDF
=========

** Under Construction ** This module aims to be a base class for basic PDF manipulation and construction. It aims to perform a similar role to Perl 5 Text::PDF module (as used by CAM::PDF and PDF::Reuse) or the PDF::API2::PDF subclassess.

## PDF::File

tba

## PDF::Page / PDF::Pages

tba

## PDF::Filter

Utility filter methods, based on PDF::API2::PDF::Filter / Text::PDF::Filter

## PDF::Objind

tba

## PDF::Writer

AST reserializer, compatible with PDF::Grammar::PDF

```
# Simple round trip read and rewrite a PDF
use v6;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Writer;

my $input-file = "t/pdf/pdf.out";
my $output-file = "examples/helloworld.pdf";

my $actions = PDF::Grammar::PDF::Actions.new;
my $pdf-content = $input-file.IO.slurp( :enc<latin1> );
PDF::Grammar::PDF.parse($pdf-content, :$actions)
    or die "unable to load pdf: $input-file";

my $pdf-ast = $/.ast;
$pdf-ast<comment> = "This PDF was brought to you by CSS::Writer!!";

my $pdf-writer = PDF::Writer.new( :input($pdf-content) );
$output-file.IO.spurt( $pdf-writer.write( :pdf($pdf-ast) ), :enc<latin1> );
```

Performs the inverse operation to PDF::Grammar. It reserializes a PDF AST back to an image;
with rebuilt cross reference tables.




