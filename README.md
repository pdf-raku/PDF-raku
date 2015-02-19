perl6-PDF-Tools
===============

** Under Construction **  This module provides tools and resources for reading, manipulation and writing of PDF content. It performs a similar role to Perl 5's Text::PDF or PDF::API2::Basic::PDF (PDF::API2 distribution). It supports reading of PDF 1.5+ object and content streams. 

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
$ast<pdf><comment>.push: "This PDF was brought to you by PDF::Tools!!";

my $root-object = $reader.root-object;
my $pdf-writer = PDF::Tools::Writer.new( :$root-object );
$output-path.IO.spurt( $pdf-writer.write( $ast ), :enc<latin1> );
```

## Status / Development Notes

This module is a proof of concept in the early stages of development.  It is also subject to change, refactoring or widthdrawal at any time.

# Classes

## PDF::Tools::Filter

Filter methods, based on PDF::API2::Core::PDF::Filter / Text::PDF::Filter

PDF::Tools::Filter::RunLength, PDF::Tools::Filter::ASCII85, PDF::Tools::Filter::Flate, ...

Input to all filters is strings, with characters in the range \x0 ... \0xFF. latin-1 encoding
is recommended to enforce this.

`encode` and `decode` both return latin-1 encoded strings.

    ```
    my $filter = PDF::Tools::Filter.new-delegate( :dict{Filter<RunlengthEncode>} );
    my $encoded = $filter.encode("This    is waaay toooooo loooong!", :eod);
    say $encoded.chars;
    ```

## PDF::Tools::IndObj

Classes for the representation and manipulation of PDF Indirect Objects.

```
use PDF::Tools::IndObj::Stream;
my %dict = :Filter( :name<ASCIIHexDecode> );
my $obj-num = 123;
my $gen-num = 4;
my $decoded = "100 100 Td (Hello, world!) Tj";
my $stream-obj = PDF::Tools::IndObj::Stream.new( :$obj-num, :$gen-num, :$dict, :$decoded );
say $stream.obj.encoded;
```

- PDF::Tools::IndObj::Stream - abstract class for stream based indirect objects - base class from Xref and Object streams, fonts and general content.
- PDF::Tools::IndObj::Dict - abstract class for dictionary based indirect objects. Root Object, Catalog, Pages tree etc.
- PDF::Tools::IndObj::Array - array indirect objects (not subclassed)
- PDF::Tools::IndObj::Bool, PDF::Tools::IndObj::Name, PDF::Tools::IndObj::Null, PDF::Tools::IndObj::Num, PDF::Tools::IndObj::String - simple indirect objects
- PDF::Tools::IndObj::Type::* - this namespace represents specific indirect object types as distinguished by the `/Type` dictionary entry. These may subclass either PDF::Tools::IndObj::Stream or PDF::Tools::IndObj::Dict.
-- PDF::Tools::IndObj::Type::Catalog - PDF Catalog dictionary
-- PDF::Tools::IndObj::Type::ObjStm - PDF 1.5+ Object stream (holds compressed objects)
-- PDF::Tools::IndObj::Type::XRef - PDF 1.5+ Cross Reference stream
-- ... many more to come

## PDF::Tools::Reader

Loads a PDF index (cross reference table and/or stream), then allows random access via the `$.ind.obj(...)` method. The `$.ast()`
method can be used to load the entire PDF into memory for reserialization, etc.

## PDF::Tools::Writer

Reserializes an AST back to a PDF image with a rebuilt cross reference table.

