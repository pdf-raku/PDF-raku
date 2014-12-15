perl6-PDF-Writer
================

Experimental AST reserializer for PDF::Grammar::PDF

## Example

```
# Simple round trip read and rewrite a PDF
use v6;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Writer;

my $input-file = "t/pdf/pdf.out";
my $output-file = "examples/helloworld.pdf";

my $actions = PDF::Grammar::PDF::Actions.new;
my $pdf-image = $input-file.IO.slurp( :encoding<latin1> );
PDF::Grammar::PDF.parse($pdf-image, :$actions)
    or die "unable to load pdf: $input-file";

my $pdf-ast = $/.ast;
$pdf-ast<comment> = "This PDF was brought to you by CSS::Writer!!";
use JSON::Tiny;note to-json($pdf-ast);

my $pdf-writer = PDF::Writer.new( :input($pdf-image) );
$output-file.IO.spurt( $pdf-writer.write( :pdf($pdf-ast) ), :encoding<latin1> );
```

## Description

This module performs the inverse operation to PDF::Grammar. It reserializes a PDF AST back to an image;
with rebuilt cross reference tables.




