perl6-PDF-Basic
===============

** Under Construction ** This module provides low-level PDF reading, manipulation and construction primitives. It performs a similar role to Perl 5's PDF::API2::Basic::PDF (PDF::API2 distribution) or Text::PDF.

## PDF::Basic::File

tba

## PDF::Basic::Page / PDF::Basic::Pages

tba

## PDF::Basic::Filter

Utility filter methods, based on PDF::API2::Basic::PDF::Filter / Text::PDF::Filter

PDF::Basic::Filter::RunLength, PDF::Basic::Filter::ASCII85, PDF::Basic::Filter::Flate, ...

Input to all filters is strings, with characters in the range \x0 ... \0xFF. latin-1 encoding
is recommended to enforce this.

`encode` and `decode` both return latin-1 encoded strings.

    ```
    my $filter = PDF::Basic::Filter::RunLength.new;
    my $data = $filter.encode("This    is waaay toooooo loooong!", :eod);
    say $data.chars;
    ```

## PDF::Basic::Objind

tba

## PDF::Basic::Writer

Performs the inverse operation to PDF::Grammar::PDF.parse. It reserializes a PDF AST back to an image;
with rebuilt cross reference tables.

```
# Simple round trip read and rewrite a PDF
use v6;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Basic;

my $input-file = "t/pdf/pdf.out";
my $output-file = "examples/helloworld.pdf";

my $actions = PDF::Grammar::PDF::Actions.new;
my $pdf-content = $input-file.IO.slurp( :enc<latin1> );
PDF::Grammar::PDF.parse($pdf-content, :$actions)
    or die "unable to load pdf: $input-file";

my $pdf-ast = $/.ast;
$pdf-ast<comment> = "This PDF was brought to you by CSS::Basic!!";

my $pdf = PDF::Basic.new( :input($pdf-content) );
$output-file.IO.spurt( $pdf.write( :pdf($pdf-ast) ), :enc<latin1> );
```
