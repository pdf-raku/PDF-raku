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

sub prefix:</>($name){ PDF::Object.coerce(:$name) };

my $Root =  PDF::Object.coerce: { :Type(/'Catalog') };
$Root<Outlines> = { :Type(/'Outlines'), :Count(0) };
$Root<Pages> = { :Type(/'Pages') };

my $page1 = PDF::Object.coerce: { :Type(/'Page'), :MediaBox[0, 0, 420, 595] };
$Root<Pages><Kids> = [ $page1 ];
$Root<Pages><Count> = 0;

my $font = PDF::Object.coerce: {
        :Type(/'Font'),
        :Subtype(/'Type1'),
        :BaseFont(/'Helvetica'),
        :Encoding(/'MacRomanEncoding'),
    };

$page1<Resources> = PDF::Object.coerce: { :Font{ :F1($font) }, :Procset[ /'PDF', /'Text'] };
$page1<Contents> = PDF::Object.coerce( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) } );

my $trailer = PDF::Object.coerce: { :$Root };
PDF::Storage::Serializer.new.save-as('/tmp/helloworld.pdf', $trailer);
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

Loads a PDF index (cross reference table and/or stream), then allows random access via the `$.ind.obj(...)` method.
The `$.ast()` method can be used to load the entire PDF into memory for reserialization, etc.

If PDF::DOM is loaded, the document can be traversed as a DOM object tree:

```
use PDF::Reader;
use PDF::DOM;
my $reader = PDF::Reader.new();
$reader.open( 't/helloworld.pdf' );
my $pdf = $reader.trailer;
my $doc = $pdf<Root>;
my $page1 = $doc<Pages><Kids>[0];

# or, using the DOM::Pages.page method
$page1 = $doc.page(1);

# objects can be directly fetched by object-number and generation-number:
$page1 = $reader.ind-obj(4, 0).object;

# the PDF can be edited using DOM functions
my $end-page = $doc.add-page();

my $font = $end-page.core-font('Times-Bold');
my $font-size = 24;
$end-page.gfx.text('The End!', 300, 50, :$font, :$font-size );
$pdf.save-as('/tmp/example.pdf');

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
my $writer = PDF::Writer.new( :$offset, :$prev );
my $new-body = "\n" ~ $writer.write( :$body );
```

# Opening and saving PDF files.

- `my $reader = PDF::Reader.open("mydoc.pdf" :repair)`
 Opens an input `PDF` (or `FDF`) document.
-- The `:repair` option causes the reader to perform a full
scan, ignoring the cross reference index and stream lengths. This can be handy if the PDF document has been edited
by hand.

- `$reader.save-as("mydoc-2.pdf", :compress, :rebuild)`
Saves a new document, including any updates. Options:
-- `:compress` - compress objects for minimal size
-- `:!compress` - uncompress objects for human redability
-- `:rebuild` - discard any unreferenced objects. reunumber remaing objects

- `$reader.save-as("mydoc.json", :compress, :rebuild)`
- my $reader2 = `$reader.open("mydoc.json")`
Documents can also be saved and restored from an intermediate `JSON` format. This can
be handy for debugging, analysis and/or ad-hoc patching of PDF files. Beware that
saving and restoring to `JSON` is somewhat slower than save/restore to `PDF`.

- `$reader.update`
This performs an incremental update to an indexed `PDF` documents (not applicable to
PDF's opened with `:repair`, unindexed FDF or JSON files). A new section is appended to the PDF that
contains only updated and newly created objects. This method can be used as a fast and efficient way to make
small updates to a large existing PDF document.

- `my $serializer = PDF::Storage::Serializer.new;
   $serializer.save-as("mynewdoc.pdf", $trailer-dict, :$type, :$version, :$compress)`
This method is used to create a new PDF from scratch. $object is the document root object (e.g a Catalog object).
-- `:trailer-dict` contains `Root` plus any additional entries to be included in the trailer dict, e.g. `ID` and `Info`. Note:
`Prev` and `First` are automatically generated.
-- `:type` is `PDF` (default) or `FDF`
-- `:version` is PDF version; Default: `1.3`
-- `:compress` can be be True, False or Mu (leave as is)


# DOM builder classes

## PDF::Object::Delegator

This forms the basis for `PDF::DOM`'s extensive library of document object classes. This
includes classes and roles for object construction, validation and serialization.

- The `PDF::Object` `coerce` methods should be used to create new Hash or Array based objects an appropriate sub-class will be chosen with the assistance of `PDF::Object::Delegator`.

- The delegator may be subclassed. For example, the upstream module `PDF::DOM` subclasses `PDF::Object::Delegator` with
`PDF::DOM::Delegator`.

## PDF::Object::Tie

This is a role used by PDF::Object. It makes the PDF object tree appear as a seamless
structure comprised of nested hashs (PDF dictionarys) and arrays.

PDF::Object::Tie::Hash and PDF::Object::Tie::Array encapsulate Hash and Array accces.

- If the object has an associated  `reader` property, indirect references are resolved lazily and transparently
as elements in the structure are dereferenced.
- Hashs and arrays automaticaly coerced to objects on assignment to a parent object. For example:


```
sub prefix:</>($name){ PDF::Object.coerce(:$name) };
my $catalog = PDF::Object.coerce({ :Type(/'Catalog') });
$catalog<Outlines> = PDF::Object.coerce( { :Type(/'Outlines'), :Count(0) } );
```

is equivalent to:

```
sub prefix:</>($name){ PDF::Object.coerce(:$name) };
my $catalog = PDF::Object.coerce({ :Type(/'Catalog') });
$catalog<Outlines> = { :Type(/'Outlines'), :Count(0) };
```

PDF::Object::Tie also provides the `entry` trait (hashes) and `index` (arrays) trait for declaring accessors.

The following demonstrates setup of DOM namespace `My::DOM` and document root class `My::DOM::Catalog`.
```
use PDF::Object::Tie;
use PDF::Object::Type;
use PDF::Object::Dict;

class My::Delegator is PDF::Object::Delegator {
    method class-paths {<My::DOM PDF::DOM::Type>}
}

PDF::Object.delegator = My::Delegator;

class My::DOM::Catalog
    is PDF::Object::Dict
    does PDF::Object::Type {

    # see [PDF 1.7 TABLE 3.25 Entries in the catalog dictionary]
    use PDF::Object::Name;
    has PDF::Object::Name $.Version is entry;        #| (Optional; PDF 1.4) The version of the PDF specification to which the document conforms (for example, /1.4) 
    has Hash $.Pages is entry(:required, :indirect); #| (Required; must be an indirect reference) The page tree node
    has Array $.Kids is entry;
    # ... etc
}
```
if we then say
```
my $Catalog = PDF::Object.coerce: { :Type( :name<Catalog> ), :Version( :name<PDF>) , :Pages{ :Type{ :name<Pages> }, :Kids[], :Count(0) } };

```
- `$Catalog` is coerced to type `My::DOM::Catalog`.
- `$Catalog.Pages` will autoload and Coerce to type `My::DOM::Pages`
- If that should fail (and there's no `PDF::Object::Type::Pages` class), it falls-back to a plain `PDF::Object::Dict` object.