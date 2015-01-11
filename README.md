perl6-PDF-Core
==============

** Under Construction ** This module provides low-level PDF reading, manipulation and construction primitives. It performs a similar role to Perl 5's PDF::API2::Basic::PDF (PDF::API2 distribution) or Text::PDF.

This is a core module. As such, it's main purpose is to implement the [PDF 1.7 specification](http://www.adobe.com/content/dam/Adobe/en/devnet/acrobat/pdfs/pdf_reference_1-7.pdf). It aims to make PDF authoring as easy and high-level as possible, but not to hide details of the PDF Specification. You will need to refer to the specification to refer to, or maintain this module. Other higher level modules (PDF::API6?) will provide a high-level abstract interface and implement additional functionality (non-core fonts, kerning, high level graphics, forms, etc).

Also not so concerned with optimization, but will support basic reading from index and lazy streams and general content handling. It many cases, stream content will be copied verbatim from input to output PDF's without the need to fully read or re-encode.

## TODO

PDF is a pretty big standard to cover in it's entirity. Initial release will be a minimal proof of concept. Handle enough funtionality to be useful in a good percentage of cases:

- reading and writing of PDF 1.4 documents
- reading and writing of PDF 1.5 - 1.7 PDFs
- inter-conversion and compatiblity from PDF 1.4 to PDF 1.5+. I.e. the ability to read/write with interconversion between classic cross reference tables and compressed and filter cross reference and object streams.
- lazy reading from cross reference tables and streams (via the Root Catalog and Pages tables etc).
- Linearized PDFs as input. These will probably have the Linearized preamble stripped on output. 
- Filters. A basic ability to input and output filters commonly associated with Object / Cross Reference streams and content. Flate (LZW?), RunLength, ASCIIHex + PNG and TIFF predictors. Other formats can be copied without the need to re-encode
- PDF Write. Serialization and write/rewrite PDF to a new file
- PDF Update. Append new sections to an existing PDF.
- Pages. The ability to insert or delete pages.
- Content - insertion of text and basic grpahics markup.
- Images - insertion of TIFF, PNG and JPEG images
- Fonts - font metrics for core fonts. Basic encoding.

## PDF::Core::Filter

Utility filter methods, based on PDF::API2::Core::PDF::Filter / Text::PDF::Filter

PDF::Core::Filter::RunLength, PDF::Core::Filter::ASCII85, PDF::Core::Filter::Flate, ...

Input to all filters is strings, with characters in the range \x0 ... \0xFF. latin-1 encoding
is recommended to enforce this.

`encode` and `decode` both return latin-1 encoded strings.

    ```
    my $filter = PDF::Core::Filter::RunLength.new;
    my $data = $filter.encode("This    is waaay toooooo loooong!", :eod);
    say $data.chars;
    ```

## PDF::Core::IndObj

- PDF::Core::IndObj::Stream - abstract class for stream based indirect objects - base class from Xref and Object streams, fonts and general content.
- PDF::Core::IndObj::Dict - abstract class for dictionary based indirect objects. Root Object, Catalog, Pages tree etc.

## PDF::Core::Writer

Performs the inverse operation to PDF::Grammar::PDF.parse. It reserializes a PDF AST back to an image;
with rebuilt cross reference tables.

```
# Simple round trip read and rewrite a PDF
use v6;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Core;

my $input-file = "t/pdf/pdf.out";
my $output-file = "examples/helloworld.pdf";

my $actions = PDF::Grammar::PDF::Actions.new;
my $pdf-content = $input-file.IO.slurp( :enc<latin1> );
PDF::Grammar::PDF.parse($pdf-content, :$actions)
    or die "unable to load pdf: $input-file";

my $pdf-ast = $/.ast;
$pdf-ast<comment> = "This PDF was brought to you by CSS::Core!!";

my $pdf = PDF::Core.new( :input($pdf-content) );
$output-file.IO.spurt( $pdf.write( :pdf($pdf-ast) ), :enc<latin1> );
```
