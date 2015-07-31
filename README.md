perl6-PDF
=========
This module provides low-level tools for reading, update and writing of PDF content.

```
#!/usr/bin/env perl6
# creates /tmp/helloworld.pdf
use v6;
use Test;

use PDF::Object;
use PDF::Storage::Serializer;
use PDF::Writer;

sub prefix:</>($name){ PDF::Object.compose(:$name) };

my $root = PDF::Object.compose( :dict{ :Type(/'Catalog') });
$root.Outlines = { :Type(/'Outlines'), :Count(0) };
$root.Pages = { :Type(/'Pages') };

$root.Pages.Kids = [ { :Type(/'Page'), :MediaBox[0, 0, 420, 595] } ];
my $page1 = $root.Pages.Kids[0];

my $font = {
        :Type(/'Font'),
        :Subtype(/'Type1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    };

$page1.Resources = { :Font{ :F1($font) }, :Procset[ /'PDF', /'Text'] };
$page1.Contents = PDF::Object.compose( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) } );

my $body = PDF::Storage::Serializer.new.body($root);

my $ast = :pdf{ :header{ :version(1.2) }, :$body };
my $writer = PDF::Writer.new( :$root );
'/tmp/helloworld.pdf'.IO.spurt( $writer.write( $ast ), :enc<latin1> );

```

# Classes

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
- PDF::Object::Array - array objects
- PDF::Object::Bool, PDF::Object::Name, PDF::Object::Null, PDF::Object::Num, PDF::Object::ByteString - simple indirect objects
- PDF 1.5+ Compressed object support (reader only). DOM objects:
  - PDF::Object::Type::ObjStm - PDF 1.5+ Object stream (holds compressed objects)
  - PDF::Object::Type::XRef - PDF 1.5+ Cross Reference stream

## PDF::Reader

Loads a PDF index (cross reference table and/or stream), then allows random access via the `$.ind.obj(...)` method. The `$.ast()`
method can be used to load the entire PDF into memory for reserialization, etc.

If PDF::DOM is loaded, the document can be traversed as a DOM object tree:

```
use PDF::Reader;
use PDF::DOM;
my $reader = PDF::Reader.new();
$reader.open( 't/helloworld.pdf' );
my $pdf = $reader.root.object;
my $page1 = $pdf<Pages><Kids>[0];

# or, using the DOM::Pages.page method
$page1 = $pdf.page(1);

# objects can be directly fetched by object-number and generation-number:
$page1 = $reader.ind-obj(4, 0).object;

# the PDF can be edited using DOM functions
my $end-page = $pdf.add-page();

my $font = $end-page.core-font('Times-Bold');
my $font-size = 24;
$end-page.gfx.text('The End!', 300, 50, :$font, :$font-size );

```

## PDF::Storage::Filter

Filter methods, based on PDF::API2::Core::PDF::Filter / Text::PDF::Filter

PDF::Storage::Filter::RunLength, PDF::Storage::Filter::ASCII85, PDF::Storage::Filter::Flate, ...

Input to all filters is strings, with characters in the range \x0 ... \0xFF. latin-1 encoding
is recommended to enforce this.

`encode` and `decode` both return latin-1 encoded strings.

 ```
 my $encoded = PDF::Storage::Filter.encode( :dict{ :Filter<RunLengthEncode> }, "This    is waaay toooooo loooong!", :eod);
 say $encoded.chars;
 ```

## PDF::Storage::Serializer

Constructs AST for output by PDF::Writer. It can create full PDF bodies, or just changes
for in-place incremental update to a PDF.

In place edits are particularly effective for making small changes to large PDF's, when we can avoid
loading large unmodified portions of the PDF.

````
my $serializer = PDF::Storage::Serializer.new;
my $body = $serializer.body( $reader, :updates );
```

## PDF::Writer

Reserializes an AST back to a PDF image with a rebuilt cross reference table.

```
my $offset = $reader.input.chars + 1;
my $prev = $body<trailer><dict><Prev>.value;
my $writer = PDF::Writer.new( :$root, :$offset, :$prev );
my $new-body = "\n" ~ $writer.write( :$body );
```

# DOM builder classess

This module also provides the framework for `PDF::DOM`'s extensive library of document object classess. This
includes classes and roles for object construction, validation and serialization.

```
```