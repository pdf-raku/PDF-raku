perl6-PDF-Core
==============

** Under Construction ** An experimental Perl 6 module that provides low-level primitives for the reading, manipulation and construction of PDF content. It performs a similar role to Perl 5's Text::PDF or PDF::API2::Basic::PDF (PDF::API2 distribution).

This is intended as a low-level module. As such, it's main purpose is to implement the [PDF 1.7 specification](http://www.adobe.com/content/dam/Adobe/en/devnet/acrobat/pdfs/pdf_reference_1-7.pdf). It aims to make PDF authoring as simple as possible, but not to hide details of the PDF Specification. Other higher level modules can potentially provide a high-level abstract interface and implement additional functionality (non-core fonts, kerning, high level graphics, forms, etc).

I'm also referring to Perl 5's Text::PDF and PDF::API2 code bases. Also looking at xpdf on occasions.

Unlike (the older) Text::PDF and PDF::API2, this module will support PDF 1.5+ object and content streams and should hopefully accept linearized PDFs as input. 

Also not so concerned with optimization, but will support basic reading from index and lazy streams and general content handling. It many cases, stream content will be copied verbatim from input to output PDF's without the need to fully process or re-encode.

## Status / Development Notes

This module is a proof of concept in the early stages of development.  It is also subject to change, refactoring or widthdrawal atany time.

PDF::Core uses the PDF::Grammar as a toolkit to parse individual PDF components. Both for parsing the top level structure of a PDF and to interpret paticular stream data, such as Object Streams and Content Streams. It isshares AST data structures with PDF::Grammar. E.g. bin/pdf-rewriter uses PDF::Grammar::PDF to read a PDF then rewrites it using PDF::Core::Writer.

## Use Cases

These are some basic use examples/cases that an initial release of PDF::Core could be expected cover.

### 1. create simple content from a PDF::Grammar compatible data structure. Reserialize 1.4 PDF.
<blockquote>done - see `t/write.ast` and `t/pdf/pdf.json`</blockquote>

#### 1a. create a simple PDF using API. Output simple "Hello World" text <em>(See Text::PDF `examples/hello.pl`)</em>
<blockquote>Discussion: This will involve creating a PDF with a adding a Page, and inserting content.</blockquote>

#### 1b. extend 1a by loading a simple image graphic. E.g. load a JPEG image from the filesystem.
<blockquote>I'll need to delve into PDF::API2. Text::PDF doesn't seem to cover this</blockquote>

#### 1c. extend 1b by adding a wrapping text-block.
<blockquote>This will require the keeping of font metrics for core fonts (to determine character sizes word-wrapping bounadries. </blockquote>

### 2. reading and writing of PDF files (bin/pdf-rewriter.pl)

#### 2a. read a version 1.4 PDF. Detect it's a 1.4 fromat. Locate xref at the tail of file. Load index then load

#### 2b. Read a version 1.5+ PDF with cross reference and object streams. Detect as 1.5+ load and parse trailer and cross reference stream. Load Object Streams. Rewrite output PDF as 1.5+ with regenerated index.

#### 2c. Read as version 1.5+ as per 2a. Rewrite as a version 1.4 PDF.

### 3. Port of scripts / examples from Perl 5's Text::PDF module

#### 3a. scripts/pdfstamp - overprint text on each page of a PDF.

#### 3b. scripts/pdfrevert - revert last changeset from a PDF

#### 3c. scripts/pdfbooklet - convert a PDF file into a booklet

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
