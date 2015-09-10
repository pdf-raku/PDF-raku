perl6-PDF
=========
This module provides low-level tools for reading, update and writing of PDF content.

```
#!/usr/bin/env perl6
# creates /tmp/helloworld.pdf
use v6;
use PDF::Object;
use PDF::Object::Doc;

sub prefix:</>($name){ PDF::Object.coerce(:$name) };

my $Root = PDF::Object.coerce: { :Type(/'Catalog') };
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

$Info = PDF::Object.coerce: { :CreationDate( DateTime.now ) };

my $pdf = PDF::Object::Doc.new: { :$Root, :$Info };
$pdf.save-as('/tmp/helloworld.pdf');
```
# Reading and Writing of PDF files:

`PDF::Object::Doc` is a base class for loading, editing and saving documents in PDF, FDF and other related formats.

- `my $doc = PDF::Object::Doc.open("mydoc.pdf" :repair)`
 Opens an input `PDF` (or `FDF`) document.
  - `:!repair` causes the read to load only the trailer dictionary and cross reference tables from the tail of the PDF (Cross Reference Table or a PDF 1.5+ Stream). Remaining objects will be lazily loaded on demand.
  - `:repair` causes the reader to perform a full scan, ignoring and recalculating the cross reference stream/index and stream lengths. This can be handy if the PDF document has been hand-edited.

- `$doc.update`
This performs an incremental update to the input pdf, which must be indexed `PDF` (not applicable to
PDF's opened with `:repair`, FDF or JSON files). A new section is appended to the PDF that
contains only updated and newly created objects. This method can be used as a fast and efficient way to make
small updates to a large existing PDF document.

- `$doc.save-as("mydoc-2.pdf", :compress, :rebuild)`
Saves a new document, including any updates. Options:
  - `:compress` - compress objects for minimal size
  - `:!compress` - uncompress objects for human redability
  - `:rebuild` - discard any unreferenced objects. reunumber remaining objects. It may be a good idea to rebuild a PDF Document, that's been incrementally updated a number of times.

Note that the `:compress` and `:rebuild` options are a trade-off. The document may take longer to save, however file-sizes and the time needed to reopen the document may improve.

- `$doc.save-as("mydoc.json", :compress, :rebuild); my $doc2 = $doc.open("mydoc.json")`
Documents can also be saved and restored from an intermediate `JSON` representation. This can
be handy for debugging, analysis and/or ad-hoc patching of PDF files. Beware that
saving and restoring to `JSON` is somewhat slower than save/restore to `PDF`.

## See also:
- `bin/pdf-rewriter.pl [--repair] [--rebuild] [--compress] [--uncompress] [--dom] <pdf-or-json-file-in> <pdf-or-json-file-out>`
This script is a thin wrapper script to the `PDF::Object::Doc` `.open` and `.save-as` methods. It can typically be used to uncompress a PDF for readability and/or repair a PDF who's cross-reference index or stream lengths have become invalid.

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

The `PDF::Object.coerce` is a method for the construction of objects.

It is used internally to build objects from parsed objects, e.g.:

```
use v6;
use PDF::Grammar::Doc;
use PDF::Grammar::Doc::Actions;
use PDF::Object;
my $actions = PDF::Grammar::Doc::Actions.new;
PDF::Grammar::Doc.parse("<< /Type /Pages /Count 1 /Kids [ 4 0 R ] >>", :rule<object>, :$actions)
    or die "parse failed";
my $ast = $/.ast;

say '#'~$ast.perl;
#:dict({:Count(:int(1)), :Kids(:array([:ind-ref([4, 0])])), :Type(:name("Pages"))})

my $object = PDF::Object.coerce( %$ast );

say '#'~$object.WHAT.gist;
#(PDF::Object::Dict)

say '#'~$object.perl;
#{:Count(1), :Kids([:ind-ref([4, 0])]), :Type("Pages")}

say '#'~$object<Type>;
#(Str+{PDF::Object::Name})

say '#'~$object<Type>.WHAT.gist;
#{:Count(1), :Kids([:ind-ref([4, 0])]), :Type("Pages")}
```
The coerce method is also used to construct new objects.

In some cases, we can omit the AST tags. E.g. we can use `1`, instead of `:int(1)`:
```
# using explicit AST tags
my $object2 = PDF::Object.coerce({ :Type( :name<Pages> ),
                                   :Count(:int(1)),
                                   :Kids( :array[ :ind-ref[4, 0] ) ] });

# same but with a casting from native typs
my $object3 = PDF::Object.coerce({ :Type( :name<Pages> ),
                                   :Count(1),
                                   :Kids[ :ind-ref[4, 0] ] });
say '#'~$object2.perl;

```

A table of Object types follows:

*AST Tag* | Object Role/Class | *Perl 6 Type | PDF Example | Description |
--- | --- | --- | --- | --- |
 `array` | PDF::Object::Array | Array | `[ 1 (foo) /Bar ]` | array objects
`bool` | PDF::Object::Bool | Bool | `true`
`int` | PDF::Object::Int | Int | `42`
`literal` | PDF::Object::ByteString (literal) | Str | `(hello world)`
`literal` | PDF::Object::DateString | DateTime | `(D:199812231952-08'00')`
`hex-string` | PDF::Object::ByteString (hex-string) | | `<736E6F6f7079>`
`dict` | PDF::Object::Dict | Hash | `<< /Length 42 /Apples(oranges) >>` | abstract class for dictionary based indirect objects. Root Object, Catalog, Pages tree etc.
`name` | PDF::Object::Name | | `/Catalog`
`null` | PDF::Object::Null | Any | `null`
`real` | PDF::Object::Real | Numeric | `3.14159`
`stream`| PDF::Object::Stream | | | abstract class for stream based indirect objects - base class from Xref and Object streams, fonts and general content.

Derived objects provided by PDF::Tools:

*Class* | *Base Class* | *Description*
--- | --- | --- |
PDF::Object::Doc | PDF::Object::Dict | the absolute root of the document- the trailer dictionary
PDF::Object::Type::ObjStm | PDF::Object::Stream | PDF 1.5+ Object stream (holds compressed objects)
PDF::Object::Type::XRef | PDF::Object::Stream | PDF 1.5+ Cross Reference stream

## PDF::Reader

Loads a PDF index (cross reference table and/or stream), then allows random access via the `$.ind.obj(...)` method.

The document can be traversed by dereferencing Array and Hash objects. The reader will load indirect objects via the index, as needed. 

If PDF::DOM is loaded, the document can be traversed as a DOM object tree:

```
use PDF
$reader.open( 't/helloworld.pdf' );

# objects can be directly fetched by object-number and generation-number:
$page1 = $reader.ind-obj(4, 0).object;

# Hashs and arrays are tied. This is usually more conveniant for navigating
my $doc = $reader.trailer<Root>;
my $page1 = $doc<Pages><Kids>[0];

# Tied objects can also be updated directly.
$pdf<Info><Creator> = PDF::Object.coerce( :name<t/helloworld.t> );

# the PDF DOM provides additional functions for navigation and composition
{
    use PDF::DOM;
    my $page = $doc.add-page();
    my $gfx = $page.gfx;

    my $bold = $page.core-font('Times-Bold');
    $gfx.set-font($bold, 24);
    $gfx.text-move(300, 50);
    $gfx.print('The End!');
}
$pdf.save-as('/tmp/example.pdf');

```

## PDF::Storage::Filter

Filters are used to compress or decompress stream data in objects of type `PDF::Object::Stream`. These are implemented as follows:

*Filter Name* | *Short Name* | Filter Class
--- | --- | ---
ASCIIHexDecode  | AHx | PDF::Storage::Filter::ASCIIHex
ASCII85Decode   | A85 | PDF::Storage::Filter::ASCII85
CCITTFaxDecode  | CCF | _NYI_
Crypt           |     | _NYI_
DCTDecode       | DCT | _NYI_
FlateDecode     | Fl  | PDF::Storage::Filter::Flate
LZWDecode       | LZW | PDF::Storage::Filter::LZW
JBIG2Decode     |     | _NYI_
JPXDecode       |     | _NYI_
RunLengthDecode | RL  | PDF::Storage::Filter::RunLength

Input to all filters is strings, with characters in the range \x0 ... \0xFF. latin-1 encoding is recommended to enforce this.

Each file has `encode` and `decode` methods. Both return latin-1 encoded strings.

 ```
 my $encoded = PDF::Storage::Filter.encode( :dict{ :Filter<RunLengthEncode> },
                                            "This    is waaay toooooo loooong!");
 say $encoded.chars;
 ```

## PDF::Storage::Serializer

Constructs AST for output by PDF::Writer. It can create full PDF bodies, or just changes for in-place incremental update to a PDF.

In place edits are particularly effective for making small changes to large PDF's, when we can avoid loading large unmodified portions of the PDF.

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

# DOM classes

## PDF::Object::Delegator

This forms the basis for `PDF::DOM`'s extensive library of document object classes. It
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
my $Catalog = PDF::Object.coerce: { :Type( :name<Catalog> ),
                                    :Version( :name<PDF>),
                                    :Pages{ :Type{ :name<Pages> }, :Kids[], :Count(0) } };

```
`$Catalog` is coerced to type `My::DOM::Catalog`.
- `$Catalog.Pages` will autoload and Coerce to type `My::DOM::Pages`
- If that should fail (and there's no `PDF::Object::Type::Pages` class), it falls-back to a plain `PDF::Object::Dict` object.

