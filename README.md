perl6-PDF-Tools
===============

** Under Construction **  This module provides tools for reading, manipulation and construction of PDF content. It performs a similar role to Perl 5's Text::PDF or PDF::API2::Basic::PDF (PDF::API2 distribution).

This module supports PDF 1.5+ object and content streams. 

## Status / Development Notes

This module is a proof of concept in the early stages of development.  It is also subject to change, refactoring or widthdrawal atany time.

PDF::Tools uses the existing PDF::Grammar as a toolkit to parse individual PDF components. Both for parsing the top level structure of a PDF and to interpret paticular stream data, such as Object Streams and Content Streams. It shares AST data structures with PDF::Grammar. E.g. bin/pdf-rewriter uses PDF::Grammar::PDF to read a PDF then rewrites it using PDF::Tools::Writer.

## TODO

PDF is a pretty big standard to cover in it's entirity. The initial release will be minimalistic, but will handle enough funtionality to be useful in a good percentage of cases:

- reading and writing of PDF 1.4 documents
- reading and writing of PDF 1.5 - 1.7 PDFs
- inter-conversion and compatiblity from PDF 1.4 to PDF 1.5+. I.e. the ability to read/write with interconversion between classic cross reference tables and compressed and filter cross reference and object streams.
- lazy reading from cross reference tables and streams (via the Root Catalog and Pages tables etc).
- Filters. A basic ability to input and output filters commonly associated with Object / Cross Reference streams and content. Flate (LZW?), RunLength, ASCIIHex + PNG and TIFF predictors. Other formats can be copied without the need to re-encode
- PDF Write. Serialization and write/rewrite PDF to a new file
- PDF Update. Append new sections to an existing PDF.
- Pages. The ability to insert or delete pages.
- Content - insertion of text and basic grpahics markup.
- Images - insertion of TIFF, PNG and JPEG images
- Fonts - font metrics for core fonts. Basic encoding.

## PDF::Tools::Filter

Toolsity filter methods, based on PDF::API2::Core::PDF::Filter / Text::PDF::Filter

PDF::Tools::Filter::RunLength, PDF::Tools::Filter::ASCII85, PDF::Tools::Filter::Flate, ...

Input to all filters is strings, with characters in the range \x0 ... \0xFF. latin-1 encoding
is recommended to enforce this.

`encode` and `decode` both return latin-1 encoded strings.

    ```
    my $filter = PDF::Tools::Filter.new-delegate( :dict{Filter<RunlengthEncode>} );
    my $data = $filter.encode("This    is waaay toooooo loooong!", :eod);
    say $data.chars;
    ```

## PDF::Tools::IndObj

- PDF::Tools::IndObj::Stream - abstract class for stream based indirect objects - base class from Xref and Object streams, fonts and general content.
- PDF::Tools::IndObj::Dict - abstract class for dictionary based indirect objects. Root Object, Catalog, Pages tree etc.

## PDF::Tools::Writer

Performs the inverse operation to PDF::Grammar::PDF.parse. It reserializes a PDF AST back to an image;
with rebuilt cross reference tables.

```
# Simple round trip read and rewrite a PDF
use v6;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Tools::Reader;

my $input-file = "t/pdf/pdf.out";
my $output-file = "examples/helloworld.pdf";

my $actions = PDF::Grammar::PDF::Actions.new;
my $pdf-content = $input-file.IO.slurp( :enc<latin1> );
PDF::Grammar::PDF.parse($pdf-content, :$actions)
    or die "unable to load pdf: $input-file";

my $pdf-ast = $/.ast;
$pdf-ast<comment> = "This PDF was brought to you by CSS::Tools!!";

my $pdf = PDF::Tools::Reader.new( :input($pdf-content) );
$output-file.IO.spurt( $pdf.write( :pdf($pdf-ast) ), :enc<latin1> );
```
