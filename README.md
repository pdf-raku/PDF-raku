perl6-PDF-Tools
===============

## Overview

perl6-PDF-Tools is an experimental low-level tool-kit for reading and manipulating data from PDF files.

It presents a seamless view of the data in PDF or FDF documents; behind the scenes handling
compression, encryption, fetching of indirect objects and unpacking of object
streams. It is capable of reading, editing and creation or incremental update of PDF files.

This module is primarily intended as base for higher level modules. It can also be used to explore or
patch data in PDF or FDF files.

It does not understand logical PDF document structure. It is however possible to construct simple documents and
perform simple edits by direct manipulation of PDF data. You will need some knowledge of how PDF documents are
structured. Please see 'The Basics' and 'Recommended Reading' sections below.

<a href="https://github.com/p6-pdf/perl6-PDF-DOM">PDF::DOM</a> and <a href="https://github.com/p6-pdf/perl6-PDF-FDF">PDF::FDF</a> are
both under construction for high-level manipulation of PDF and FDF documents.

Classes/roles in this tool-kit include:

- `PDF::Reader` - for indexed random access to PDFs
- `PDF::Storage::Filter` - a collection of standard PDF decoding and encoding tools for PDF data streams
- `PDF::Storage::IndObj` - base class for indirect objects
- `PDF::Storage::Serializer` - data marshalling utilities for the preparation of full or incremental updates
- `PDF::Storage::Crypt` - decryption / encryption (V 2 & 3 RC4 only at this stage)
- `PDF::Writer` - for the creation or update of PDFs
- `PDF::DAO` - an intermediate Data Access and Object representation layer (<a href="https://en.wikipedia.org/wiki/Data_access_object">DAO</a>) to PDF data structures. Base classes for PDF::DOM

## Example Usage

To create a one page PDF that displays 'Hello, World!'.

```
#!/usr/bin/env perl6
# creates t/helloworld.pdf
use v6;
use PDF::DAO;
use PDF::DAO::Doc;

sub prefix:</>($name){ PDF::DAO.coerce(:$name) };

my @MediaBox  = 0, 0, 420, 595;
my %Resources = :Procset[ /'PDF', /'Text'],
                :Font{
                    :F1{
                        :Type(/'Font'),
                        :Subtype(/'Type1'),
                        :BaseFont(/'Helvetica'),
                        :Encoding(/'MacRomanEncoding'),
                    },
                };

my $doc = PDF::DAO::Doc.new;
my $root     = $doc.Root       = { :Type(/'Catalog') };
my $outlines = $root<Outlines> = { :Type(/'Outlines'), :Count(0) };
my $pages    = $root<Pages>    = { :Type(/'Pages'), :@MediaBox, :%Resources, :Kids[], :Count(0), };

my $Contents = PDF::DAO.coerce( :stream{ :decoded("BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET" ) });
$pages<Kids>.push: { :Type(/'Page'), :Parent($pages), :$Contents };
$pages<Count>++;

my $info = $doc.Info = {};
$info.CreationDate = DateTime.now;
$info.Author = 'PDF-Tools/t/helloworld.t';

$doc.save-as: 't/helloworld.pdf';
```

Then to update the PDF, adding another page:

```
use v6;
use PDF::DAO::Doc;

my $doc = PDF::DAO::Doc.open: 't/helloworld.pdf';

my $catalog = $doc<Root>;
my $Parent = $catalog<Pages>;
my $Contents = PDF::DAO.coerce( :stream{ :decoded("BT /F1 16 Tf  90 250 Td (Goodbye for now!) Tj ET" ) } );
$Parent<Kids>.push: { :Type(/'Page'), :$Parent, :$Contents };
$Parent<Count>++;

my $info = $doc.Info //= {};
$info.ModDate = DateTime.now;
$doc.update;
```

## Description

A PDF file consists of data structures, including dictionarys (hashs) arrays, numbers and strings, plus streams
for holding data such as images, fonts and general content.

PDF files are also indexed for random access and may also have filters for stream compression and encryption of streams and strings.

They have a reasonably well specified structure. The document structure starts from
`Root` entry in the trailer dictionary, which is the main entry point into a PDF.

This module is based on the <a href='http://www.adobe.com/content/dam/Adobe/en/devnet/acrobat/pdfs/pdf_reference_1-7.pdf'>PDF Reference version 1.7<a> specification. It implements syntax, basic data-types, serialization and encryption rules as described in the first four chapters of the specification. Read and write access to data structures is via direct manipulation of tied arrays and hashes.

`PDF::DAO` provides a set of class builder utilities to enable higher level classes for general application development.

This is put to work in the companion module <a href="https://github.com/p6-pdf/perl6-PDF-DOM">PDF::DOM</a> (under construction), which contains a much more detailed set of classes to implement much of the remainder of the PDF specification.

## The Basics

PDF files are serialized as numbered indirect objects. The `t/helloworld.pdf` file that we just wrote contains:
```
%PDF-1.3
%...(control chars)
1 0 obj <<
  /Author (PDF-Tools/t/helloworld.t)
  /CreationDate (D:20151225000000Z00'00')
>>
endobj
2 0 obj <<
  /Type /Catalog
  /Outlines 3 0 R
  /Pages 4 0 R
>>
endobj
3 0 obj <<
  /Type /Outlines
  /Count 0
>>
endobj
4 0 obj <<
  /Type /Pages
  /Count 1
  /Kids [ 5 0 R ]
  /MediaBox [ 0 0 420 595 ]
  /Resources <<
    /Font <<
      /F1 7 0 R
    >>
    /Procset [ /PDF /Text ]
  >>
>>
endobj
5 0 obj <<
  /Type /Page
  /Contents 6 0 R
  /Parent 4 0 R
>>
endobj
6 0 obj <<
  /Length 46
>>
stream
BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET
endstream
endobj
7 0 obj <<
  /Type /Font
  /Subtype /Type1
  /BaseFont /Helvetica
  /Encoding /MacRomanEncoding
>>
endobj
xref
0 8
0000000000 65535 f 
0000000014 00000 n 
0000000114 00000 n 
0000000185 00000 n 
0000000235 00000 n 
0000000413 00000 n 
0000000482 00000 n 
0000000580 00000 n 
trailer
<<
  /ID [ <4386dc7bc3489e418b44434e3a168843> <4386dc7bc3489e418b44434e3a168843> ]
  /Info 1 0 R
  /Root 2 0 R
  /Size 8
>>
startxref
686
%%EOF
```

The PDF is composed of a series indirect objects, for example, the first object is:

```
1 0 obj <<
  /Author (PDF-Tools/t/helloworld.t)
  /CreationDate (D:20151225000000Z00'00')
>>
endobj
```

It's an indirect object with object number `1` and generation number `0`, containing the author and the date that the document was created.

This is a PDF dictionary object which is roughly equivalent to a Perl 6 hash:

``` { :Author("PDF-Tools/t/helloworld.t"), :CreationDate("D:20151225000000Z00'00'") } ```

The bottom of the PDF contains

```
trailer
<<
  /ID [ <4386DC7BC3489E418B44434E3A168843> <4386DC7BC3489E418B44434E3A168843> ]
  /Info 1 0 R
  /Root 2 0 R
  /Size 8
>>
```

This is the trailer dictionary and the main entry point into the document. The dictionary entry `/Info 1 0 R`
is an indirect reference to the first object (object number 1, generation 0) described above.

We can quickly put PDF Tools to work using a Perl 6 REPL, to better explore the document:

```
snoopy: ~/git/perl6-PDF-Tools $ perl6 -MPDF::DAO::Doc
> my $doc = PDF::DAO::Doc.open: "t/helloworld.pdf"
ID => [CÜ{ÃHADCN:C CÜ{ÃHADCN:C], Info => ind-ref => [1 0], Root => ind-ref => [2 0]
> $doc.keys
(Root Info ID)
```
This is the root of the PDF, loaded from the trailer dictionary
```
> $doc<Info>
Author => PDF-Tools/t/helloworld.t, CreationDate => D:20151225000000Z00'00'
```
That's the document information entry, commonly used to store basic meta-data about the document.

(PDF Tools has conveniantly fetched indirect object 1 from the PDF, when we dereferenced this entry).
```
> $doc<Root>
Outlines => ind-ref => [3 0], Pages => ind-ref => [4 0], Type => Catalog
````
The trailer `Root` entry references the document catalog, which contains the actual PDF content. Exploring
further; the catalog potentially contains a number of pages, each with content.
```
> $doc<Root><Pages>
Count => 1, Kids => [ind-ref => [5 0]], Type => Pages
> $doc<Root><Pages><Kids>[0]
Contents => ind-ref => [6 0], MediaBox => [0 0 420 595], Parent => ind-ref => [4 0], Resources => Font => F1 => ind-ref => [7 0], Procset => [PDF Text], Type => Page
> $doc<Root><Pages><Kids>[0]<Contents>
Length => 46
> $doc<Root><Pages><Kids>[0]<Contents>.decoded
BT /F1 24 Tf  100 250 Td (Hello, world!) Tj ET
> 
```

The page `Contents` is a PDF stream which contains graphical instructions. In the above example, to output the text `Hello, world!` at coordinates 100, 250.

## Datatypes and Coercian

The `PDF::DAO` namespace provides roles and classes for the representation and manipulation of PDF objects.

```
use PDF::DAO::Stream;
my %dict = :Filter( :name<ASCIIHexDecode> );
my $obj-num = 123;
my $gen-num = 4;
my $decoded = "100 100 Td (Hello, world!) Tj";
my $stream-obj = PDF::DAO::Stream.new( :$obj-num, :$gen-num, :$dict, :$decoded );
say $stream.obj.encoded;
```

`PDF::DAO.coerce` is a method for the construction of objects.

It is used internally to build objects from parsed AST data, e.g.:

```
use v6;
use PDF::Grammar::Doc;
use PDF::Grammar::Doc::Actions;
use PDF::DAO;
my $actions = PDF::Grammar::Doc::Actions.new;
PDF::Grammar::Doc.parse("<< /Type /Pages /Count 1 /Kids [ 4 0 R ] >>", :rule<object>, :$actions)
    or die "parse failed";
my $ast = $/.ast;

say '#'~$ast.perl;
#:dict({:Count(:int(1)), :Kids(:array([:ind-ref([4, 0])])), :Type(:name("Pages"))})

my $object = PDF::DAO.coerce( %$ast );

say '#'~$object.WHAT.gist;
#(PDF::DAO::Dict)

say '#'~$object.perl;
#{:Count(1), :Kids([:ind-ref([4, 0])]), :Type("Pages")}

say '#'~$object<Type>;
#(Str+{PDF::DAO::Name})

say '#'~$object<Type>.WHAT.gist;
#{:Count(1), :Kids([:ind-ref([4, 0])]), :Type("Pages")}
```
The `PDF::DAO.coerce` method is also used to construct new objects from application data.

In many cases, AST tags will coerce if omitted. E.g. we can use `1`, instead of `:int(1)`:
```
# using explicit AST tags
my $object2 = PDF::DAO.coerce({ :Type( :name<Pages> ),
                                :Count(:int(1)),
                                :Kids( :array[ :ind-ref[4, 0] ) ] });

# same but with a casting from native typs
my $object3 = PDF::DAO.coerce({ :Type( :name<Pages> ),
                                :Count(1),
                                :Kids[ :ind-ref[4, 0] ] });
say '#'~$object2.perl;

```

A table of Object types and coercements follows:

*AST Tag* | Object Role/Class | *Perl 6 Type Coercian | PDF Example | Description |
--- | --- | --- | --- | --- |
 `array` | PDF::DAO::Array | Array | `[ 1 (foo) /Bar ]` | array objects
`bool` | PDF::DAO::Bool | Bool | `true`
`int` | PDF::DAO::Int | Int | `42`
`literal` | PDF::DAO::ByteString (literal) | Str | `(hello world)`
`literal` | PDF::DAO::DateString | DateTime | `(D:199812231952-08'00')`
`hex-string` | PDF::DAO::ByteString (hex-string) | | `<736E6F6f7079>`
`dict` | PDF::DAO::Dict | Hash | `<< /Length 42 /Apples(oranges) >>` | abstract class for dictionary based indirect objects. Root Object, Catalog, Pages tree etc.
`name` | PDF::DAO::Name | | `/Catalog`
`null` | PDF::DAO::Null | Any | `null`
`real` | PDF::DAO::Real | Numeric | `3.14159`
`stream`| PDF::DAO::Stream | | | abstract class for stream based indirect objects - base class from Xref and Object streams, fonts and general content.

`PDF::DAO` also provides a few essential derived classes:

*Class* | *Base Class* | *Description*
--- | --- | --- |
PDF::DAO::Doc | PDF::DAO::Dict | document entry point - the trailer dictionary
PDF::DAO::Type::Encrypt | PDF::DAO::Dict | PDF Encryption/Permissions dictionary
PDF::DAO::Type::Info | PDF::DAO::Dict | Document Information Dictionary
PDF::DAO::Type::ObjStm | PDF::DAO::Stream | PDF 1.5+ Object stream (holds compressed objects)
PDF::DAO::Type::XRef | PDF::DAO::Stream | PDF 1.5+ Cross Reference stream

## Reading and Writing of PDF files:

`PDF::DAO::Doc` is a base class for loading, editing and saving documents in PDF, FDF and other related formats.

- `my $doc = PDF::DAO::Doc.open("mydoc.pdf" :repair)`
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
be handy for debugging, analysis and/or ad-hoc patching of PDF files.

### See also:
- `bin/pdf-rewriter.pl [--repair] [--rebuild] [--compress] [--uncompress] [--dom] [--password=Xxx] <pdf-or-json-file-in> <pdf-or-json-file-out>`
This script is a thin wrapper for the `PDF::DAO::Doc` `.open` and `.save-as` methods. It can typically be used to uncompress a PDF for readability and/or repair a PDF who's cross-reference index or stream lengths have become invalid.

### Reading PDF Files

The `PDF::Reader` `.open` method loads a PDF index (cross reference table and/or stream). The document can then be access randomly via the
`.ind.obj(...)` method.

The document can be traversed by dereferencing Array and Hash objects. The reader will load indirect objects via the index, as needed. 

```
use PDF
$reader.open( 't/helloworld.pdf' );

# objects can be directly fetched by object-number and generation-number:
$page1 = $reader.ind-obj(4, 0).object;

# Hashs and arrays are tied. This is usually more conveniant for navigating
my $doc = $reader.trailer<Root>;
my $page1 = $doc<Pages><Kids>[0];

# Tied objects can also be updated directly.
$pdf<Info><Creator> = PDF::DAO.coerce( :name<t/helloworld.t> );
```

### Decode Filters

Filters are used to compress or decompress stream data in objects of type `PDF::DAO::Stream`. These are implemented as follows:

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

### Serialization

PDF::Storage::Serializer constructs AST for output by PDF::Writer. It can create full PDF bodies, or just changes for in-place incremental update to a PDF.

In place edits are particularly effective for making small changes to large PDF's, when we can avoid loading large unmodified portions of the PDF.

````
my $serializer = PDF::Storage::Serializer.new;
my $body = $serializer.body( $reader, :updates );
```

PDF::Writer then converts the AST back to a PDF byte image, with a rebulilt cross reference index.

```
my $offset = $reader.input.codes + 1;
my $prev = $body<trailer><dict><Prev>.value;
my $writer = PDF::Writer.new( :$offset, :$prev );
my $new-body = "\n" ~ $writer.write( :$body );

```
## Data Access Objects

`PDF::DAO` is roughly equivalent to an <a href="https://en.wikipedia.org/wiki/Object-relational_mapping">ORM</a> in that it provides the ability to define and map Perl 6 classes to PDF structures whilst hiding details of serialization and internal representations.

It's subclasses and used by `PDF::DOM` to build the extenstive library of document specific classes in the `PDF::DOM::Type` namespace.

The following outlines the setup, from scratch, of document mapped classes with root `MyPDF::Catalog`.
```
use PDF::DAO::Tie;
use PDF::DAO::Type;
use PDF::DAO::Dict;

class My::Delegator is PDF::DAO::Delegator {
    method class-paths {<MyPDF PDF::DAO::Type>}
}

PDF::DAO.delegator = My::Delegator;

class MyPDF::Pages
    is PDF::DAO::Dict
    does PDF::Oject::Type {

    has MyPDF::Page @.Kids is entry(:required, :indirect);
}

class MyPDF::Catalog
    is PDF::DAO::Dict
    does PDF::DAO::Type {

    # see [PDF 1.7 TABLE 3.25 Entries in the catalog dictionary]
    use PDF::DAO::Name;
    has PDF::DAO::Name $.Version is entry;        #| (Optional; PDF 1.4) The version of the PDF specification to which the document conforms (for example, /1.4) 
    has MyPDF::Pages $.Pages is entry(:required, :indirect); #| (Required; must be an indirect reference) The page tree node
    # ... etc
}
```
if we then say
```
my $Catalog = PDF::DAO.coerce: { :Type( :name<Catalog> ),
                                 :Version( :name<PDF>),
                                 :Pages{ :Type{ :name<Pages> }, :Kids[], :Count(0) } };

```
`$Catalog` is coerced to type `MyPDF::Catalog`.
- `$Catalog.Pages` will autoload and Coerce to type `MyPDF::Pages`
- If that should fail (and there's no `PDF::DAO::Type::Pages` class), it falls-back to a plain `PDF::DAO::Dict` object.

## Further Reading

- [PDF Explained](http://shop.oreilly.com/product/0636920021483.do) By John Whitington (120pp) - Offers an excellent overview of the PDF format.
- [PDF Reference version 1.7](http://www.adobe.com/content/dam/Adobe/en/devnet/acrobat/pdfs/pdf_reference_1-7.pdf) Adobe Systems Incorporated - This is the main reference used in the construction of this module.

## See also

- [PDF::Grammar](https://github.com/p6-pdf/perl6-PDF-Grammar) - base grammars for PDF parsing
- [PDF::DOM](https://github.com/p6-pdf/perl6-PDF-DOM) - PDF Document Object Model (under construction)

