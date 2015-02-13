perl6-PDF-Tools
===============

** Under Construction **  This module provides tools for reading, manipulation and construction of PDF content. It performs a similar role to Perl 5's Text::PDF or PDF::API2::Basic::PDF (PDF::API2 distribution). It supports PDF 1.5+ object and content streams. 

```
use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Tools::Reader;
use PDF::Tools::Writer;

my $input-path = "t/pdf/pdf.in";
my $output-path = "examples/helloworld.pdf";

my $reader = PDF::Tools::Reader.new;
 
$reader.open( $input-path );
my $ast = $reader.ast;
note :$ast.perl;
$ast<pdf><comment> = "This PDF was brought to you by PDF::Tools!!";

my $root-object = $reader.root-object;
my $pdf-writer = PDF::Tools::Writer.new( :$root-object );
$output-path.IO.spurt( $pdf-writer.write( $ast ), :enc<latin1> );
```

## Status / Development Notes

This module is a proof of concept in the early stages of development.  It is also subject to change, refactoring or widthdrawal at any time.

PDF::Tools uses the existing PDF::Grammar as a toolkit to parse individual PDF components. Both for parsing the top level structure of a PDF and to interpret paticular stream data, such as Object Streams and Content Streams. It shares AST data structures with PDF::Grammar. E.g. bin/pdf-rewriter uses PDF::Grammar::PDF to read a PDF then rewrites it using PDF::Tools::Writer.

## PDF::Tools::Filter

Filter methods, based on PDF::API2::Core::PDF::Filter / Text::PDF::Filter

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

## PDF::Tools::Reader

Reads a PDF file from the cross reference tables and/or streams.

## PDF::Tools::Writer

Reserializes an AST back to a PDF image with rebuilt cross reference streams (PDF 1.5+) or tables.

