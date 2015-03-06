perl6-PDF
=========

** Under Construction **  This module provides tools and resources for manipulation of PDF content.

```
use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Reader;
use PDF::Writer;

my $input-path = "t/pdf/pdf.in";
my $output-path = "examples/helloworld.pdf";

my $reader = PDF::Reader.new;
 
$reader.open( $input-path );
my $ast = $reader.ast;
note :$ast.perl;
$ast<pdf><comment>.push: "This PDF was brought to you by PDF::Tools!!";

my $root-object = $reader.root-object;
my $pdf-writer = PDF::Writer.new( :$root-object );
$output-path.IO.spurt( $pdf-writer.write( $ast ), :enc<latin1> );
```

## Status / Development Notes

This module is a proof of concept in the early stages of development.  It is subject to change, refactoring or reorganization  at any time.

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

## PDF::Object

Classes for the representation and manipulation of PDF Objects.

```
use PDF::Object::Stream;
my %dict = :Filter( :name<ASCIIHexDecode> );
my $obj-num = 123;
my $gen-num = 4;
my $decoded = "100 100 Td (Hello, world!) Tj";
my $stream-obj = PDF::Object::Stream.new( :$obj-num, :$gen-num, :$dict, :$decoded );
say $stream.obj.encoded;
```

- PDF::Object::Stream - abstract class for stream based indirect objects - base class from Xref and Object streams, fonts and general content.
- PDF::Object::Dict - abstract class for dictionary based indirect objects. Root Object, Catalog, Pages tree etc.
- PDF::Object::Array - array indirect objects (not subclassed)
- PDF::Object::Bool, PDF::Object::Name, PDF::Object::Null, PDF::Object::Num, PDF::Object::String - simple indirect objects
- PDF::Object::Type::* - this namespace represents specific indirect object types as distinguished by the `/Type` dictionary entry. These may subclass either PDF::Object::Stream or PDF::Object::Dict.
  - PDF::Object::Type::Catalog - PDF Catalog dictionary
  - PDF::Object::Type::ObjStm - PDF 1.5+ Object stream (holds compressed objects)
  - PDF::Object::Type::XRef - PDF 1.5+ Cross Reference stream
  - ... many more to come

## PDF::Reader

Loads a PDF index (cross reference table and/or stream), then allows random access via the `$.ind.obj(...)` method. The `$.ast()`
method can be used to load the entire PDF into memory for reserialization, etc.

## PDF::Writer

Reserializes an AST back to a PDF image with a rebuilt cross reference table.

