[[Raku PDF Project]](https://pdf-raku.github.io)
 / [PDF](https://pdf-raku.github.io/PDF-raku)

[![Actions Status](https://github.com/pdf-raku/PDF-raku/workflows/test/badge.svg)](https://github.com/pdf-raku/PDF-raku/actions)

PDF-raku
========

## Overview

This is a low-level Raku module for accessing and manipulating data from PDF documents.

It presents a seamless view of the data in PDF or FDF documents; behind the scenes handling indexing, compression, encryption, fetching of indirect objects and unpacking of object streams. It is capable of reading, editing and creation or incremental update of PDF files.

This module understands physical data structures rather than the logical document structure. It is primarily intended as base for higher level modules; or to explore or patch data in PDF or FDF files.

It is possible to construct basic documents and perform simple edits by direct manipulation of PDF data. This requires some knowledge of how PDF documents are structured. Please see 'The Basics' and 'Recommended Reading' sections below.

Classes/roles in this module include:

- `PDF` - PDF document root (trailer)
- `PDF::IO::Reader` - for indexed random access to PDF files
- `PDF::IO::Filter` - a collection of standard PDF decoding and encoding tools for PDF data streams
- `PDF::IO::IndObj` - base class for indirect objects
- `PDF::IO::Serializer` - data marshalling utilities for the preparation of full or incremental updates
- `PDF::IO::Crypt` - decryption / encryption
- `PDF::IO::Writer` - for the creation or update of PDF files
- `PDF::COS` - Raku Bindings to PDF objects [Carousel Object System, see <a href="http://jimpravetz.com/blog/2012/12/in-defense-of-cos/">COS</a>]

## Example Usage

To create a one page PDF that displays 'Hello, World!'.

```
#!/usr/bin/env raku
# creates examples/helloworld.pdf
use PDF;
use PDF::COS::Name;
use PDF::COS::Dict;
use PDF::COS::Stream;
use PDF::COS::Type::Info;

sub prefix:</>($s) { PDF::COS::Name.COERCE($s) };

# construct a simple PDF document from scratch
my PDF $pdf .= new;
my PDF::COS::Dict $catalog = $pdf.Root = { :Type(/'Catalog') };

my @MediaBox  = 0, 0, 250, 100;

# define font /F1 as core-font Helvetica
my %Resources = :Font{
                    :F1{
                        :Type(/'Font'),
                        :Subtype(/'Type1'),
                        :BaseFont(/'Helvetica'),
                        :Encoding(/'MacRomanEncoding'),
                    },
                };

my PDF::COS::Dict $page-index = $catalog<Pages> = { :Type(/'Pages'), :@MediaBox, :%Resources, :Kids[], :Count(0) };
# add some standard metadata
my PDF::COS::Type::Info $info = $pdf.Info //= {};
$info.CreationDate = DateTime.now;
$info.Producer = "Raku PDF";

# define some basic content
my PDF::COS::Stream() $Contents = { :decoded("BT /F1 24 Tf  15 25 Td (Hello, world!) Tj ET" ) };

# create a new page. add it to the page tree
$page-index<Kids>.push: { :Type(/'Page'), :Parent($page-index), :$Contents };
$page-index<Count>++;

# save the PDF to a file
$pdf.save-as: 'examples/helloworld.pdf';
```

![example.pdf](examples/.previews/helloworld-001.png)

Then to update the PDF, adding another page:

```
#!/usr/bin/env raku
use PDF;
use PDF::COS::Stream;
use PDF::COS::Type::Info;

my PDF $pdf .= open: 'examples/helloworld.pdf';

# locate the document root and page tree
my $catalog = $pdf<Root>;
my $Parent = $catalog<Pages>;

# create additional content, use existing font /F1
my PDF::COS::Stream() $Contents = { :decoded("BT /F1 16 Tf  15 25 Td (Goodbye for now!) Tj ET" ) };

# create a new page. add it to the page-tree
$Parent<Kids>.push: { :Type( :name<Page> ), :$Parent, :$Contents };
$Parent<Count>++;

# update or create document metadata. set modification date
my PDF::COS::Type::Info $info = $pdf.Info //= {};
$info.ModDate = DateTime.now;

# incrementally update the existing PDF
$pdf.update;
```

![example.pdf](examples/.previews/helloworld-002.png)


## Description

A PDF file consists of data structures, including dictionaries (hashes) arrays, numbers and strings, plus streams for holding graphical data such as images, fonts and general content.

PDF files are also indexed for random access and may also have internal compression and/or encryption.

They have a reasonably well specified structure. The document starts from the `Root` entry in the trailer dictionary, which is the main entry point into a PDF.

This module is based on the [PDF 32000-1:2008 1.7](https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf) specification. It implements syntax, basic data-types, serialization and encryption rules as described in the first four chapters of the specification. Read and write access to data structures is via direct manipulation of tied arrays and hashes.

## The Basics

The `examples/helloworld.pdf` file that we created above contains:
```
%PDF-1.4
%...(control characters)
1 0 obj
<< /CreationDate (D:20151225000000Z00'00') /Producer (Raku PDF) >>
endobj

2 0 obj
<< /Type /Catalog /Pages 3 0 R >>
endobj

3 0 obj
<<
  /Type /Pages
  /Count 1
  /Kids [ 4 0 R ]
  /MediaBox [ 0 0 250 100 ]
  /Resources << /Font << /F1 6 0 R >> >>
>>
endobj

4 0 obj
<< /Type /Page /Contents 5 0 R /Parent 3 0 R >>
endobj

5 0 obj
<< /Length 44 >> stream
BT /F1 24 Tf  15 25 Td (Hello, world!) Tj ET
endstream
endobj

6 0 obj
<<
  /Type /Font
  /Subtype /Type1
  /BaseFont /Helvetica
  /Encoding /MacRomanEncoding
>>
endobj

xref
0 7
0000000000 65535 f 
0000000015 00000 n 
0000000098 00000 n 
0000000148 00000 n 
0000000283 00000 n 
0000000347 00000 n 
0000000442 00000 n 
trailer
<<
  /ID [ <2086649e71c387e1fd583111ee195fe5> <2086649e71c387e1fd583111ee195fe5> ]
  /Info 1 0 R
  /Root 2 0 R
  /Size 7
>>
startxref
549
%%EOF```

The PDF is composed of a series indirect objects, for example, the first object is:

```
1 0 obj <<
  /CreationDate (D:20151225000000Z00'00')
  /Producer (Raku PDF)
>> endobj
```

It's an indirect object with object number `1` and generation number `0`, with a `<<` ... `>>` delimited dictionary containing the author and the date that the document was created. This PDF dictionary is roughly equivalent to the Raku hash:

``` { :CreationDate("D:20151225000000Z00'00'"), :Producer("Raku PDF"), } ```

The bottom of the PDF contains:

```
trailer
<<
  /ID [ <d743a886fcdcf87b69c36548219ea941> <d743a886fcdcf87b69c36548219ea941> ]
  /Info 1 0 R
  /Root 2 0 R
  /Size 7
>>
startxref
610
%%EOF
```

The `<<` ... `>>` delimited section is the trailer dictionary and the main entry point into the document. The entry `/Info 1 0 R` is an indirect reference to the first object (object number 1, generation 0) described above. The entry `/Root 2 0 R` points the root of the actual PDF document,
commonly known as the Document Catalog.

Immediately above the trailer is the cross reference table:

```
xref
0 7
0000000000 65535 f 
0000000014 00000 n 
0000000101 00000 n 
0000000155 00000 n 
0000000334 00000 n 
0000000404 00000 n 
0000000501 00000 n 
```

This indexes the indirect objects in the PDF by byte offset (generation number) for random access.

We can quickly put PDF to work using the Raku REPL, to better explore the document:

    snoopy: ~/git/PDF-raku $ raku -M PDF
    > my $pdf = PDF.open: "examples/helloworld.pdf"
    ID => [CÜ{ÃHADCN:C CÜ{ÃHADCN:C], Info => ind-ref => [1 0], Root => ind-ref => [2 0]
    > $pdf.keys
    (Root Info ID)

This is the root of the PDF, loaded from the trailer dictionary

    > $pdf<Info>
    {CreationDate => D:20151225000000Z00'00', ModDate => D:20151225000000Z00'00', Producer => Raku PDF}

That's the document information entry, commonly used to store basic meta-data about the document.

(PDF::IO has conveniently fetched indirect object 1 from the PDF, when we dereferenced this entry).

    > $pdf<Root>
    {Pages => ind-ref => [3 0], Type => Catalog}

The trailer `Root` entry references the document catalog, which contains the actual PDF content. Exploring further; the catalog potentially contains a number of pages, each with content.

    > $pdf<Root><Pages>
    {Count => 1, Kids => [ind-ref => [4 0]], MediaBox => [0 0 420 595], Resources => Font => F1 => ind-ref => [6 0], Type => Pages}
    > $pdf<Root><Pages><Kids>[0]
    {Contents => ind-ref => [5 0], Parent => ind-ref => [3 0], Type => Page}
    > $pdf<Root><Pages><Kids>[0]<Contents>
    {Length => 44}
    "BT /F1 24 Tf  15 25 Td (Hello, world!) Tj ET"

The page `/Contents` entry is a PDF stream which contains graphical instructions. In the above example, to output the text `Hello, world!` at coordinates 100, 250.

## Reading and Writing of PDF files:

`PDF` is a base class for opening or creating PDF documents.

- `my $pdf = PDF.open("mydoc.pdf" :repair)`
 Opens an input `PDF` (or `FDF`) document.
  - `:!repair` causes the read to load only the trailer dictionary and cross reference tables from the tail of the PDF (Cross Reference Table or a PDF 1.5+ Stream). Remaining objects will be lazily loaded on demand.
  - `:repair` causes the reader to perform a full scan, ignoring and recalculating the cross reference stream/index and stream lengths. This can be handy if the PDF document has been hand-edited.

- `$pdf.update`
This performs an incremental update to the input pdf, which must be indexed `PDF` (not applicable to PDFs opened with `:repair`, FDF or JSON files). A new section is appended to the PDF that contains only updated and newly created objects. This method can be used as a fast and efficient way to make small updates to a large existing PDF document.
    - `:diffs(IO::Handle $fh)` - saves just the updates to an alternate location. This can be later appended to the base PDF to reproduce the updated PDF.

- `$pdf.save-as("mydoc-2.pdf", :compress, :stream, :preserve, :rebuild)`
Saves a new document, including any updates. Options:
  - `:compress` - compress objects for minimal size
  - `:!compress` - uncompress objects for human readability
  - `:stream` - write the PDF progressively
  - `:preserve` - copy the input PDF, then incrementally update. This is generally faster and ensures that any digital signatures are not invalidated,
  - `:rebuild` - discard any unreferenced objects. renumber remaining objects. It may be a good idea to rebuild a PDF Document, that's been incrementally updated a number of times.

Note that the `:compress` and `:rebuild` options are a trade-off. The document may take longer to save, however file-sizes and the time needed to reopen the document may improve.

- `$pdf.save-as("mydoc.json", :compress, :rebuild); my $pdf2 = $pdf.open: "mydoc.json"`
Documents can also be saved and opened from an intermediate `JSON` representation. This can be handy for debugging, analysis and/or ad-hoc patching of PDF files.

### Reading PDF Files

The `.open` method loads a PDF index (cross reference table and/or stream). The document can then be access randomly via the
`.ind.obj(...)` method.

The document can be traversed by dereferencing Array and Hash objects. The reader will load indirect objects via the index, as needed. 

```
use PDF::IO::Reader;
use PDF::COS::Name;

my PDF::IO::Reader $reader .= new;
$reader.open: 'examples/helloworld.pdf';

# objects can be directly fetched by object-number and generation-number:
my $page1 = $reader.ind-obj(4, 0).object;

# Hashes and arrays are tied. This is usually more convenient for navigating
my $pdf = $reader.trailer<Root>;
$page1 = $pdf<Pages><Kids>[0];

# Tied objects can also be updated directly.
$reader.trailer<Info><Creator> = PDF::COS::Name.COERCE: 't/helloworld.t';
```

### Utility Scripts
- `pdf-rewriter.raku [--repair] [--rebuild] [--stream] [--[/]compress] [--password=Xxx] [--decrypt] [--class=Module] [--render] <pdf-or-json-file-in> [<pdf-or-json-file-out>]`
This script is a thin wrapper for the `PDF` `.open` and `.save-as` methods. It can typically be used to:
  - uncompress or render a PDF for human readability
  - repair a PDF who's cross-reference index or stream lengths have become invalid
  - convert between PDF and JSON

### Decode Filters

Filters are used to compress or decompress stream data in objects of type `PDF::COS::Stream`. These are implemented as follows:

*Filter Name* | *Short Name* | Filter Class
--- | --- | ---
ASCIIHexDecode  | AHx | PDF::IO::Filter::ASCIIHex
ASCII85Decode   | A85 | PDF::IO::Filter::ASCII85
CCITTFaxDecode  | CCF | _NYI_
Crypt           |     | _NYI_
DCTDecode       | DCT | _NYI_
FlateDecode     | Fl  | PDF::IO::Filter::Flate
LZWDecode       | LZW | PDF::IO::Filter::LZW (`decode` only)
JBIG2Decode     |     | _NYI_
JPXDecode       |     | _NYI_
RunLengthDecode | RL  | PDF::IO::Filter::RunLength

Input to all filters is byte strings, with characters in the range \x0 ... \0xFF. latin-1 encoding is recommended to enforce this.

Each filter has `encode` and `decode` methods, which accept and return latin-1 encoded strings, or binary blobs.

```
my Blob $encoded = PDF::IO::Filter.encode( :dict{ :Filter<RunLengthDecode> },
                                      "This    is waaay toooooo loooong!");
say $encoded.bytes;
 ```

### Encryption

PDF::IO::Crypt supports RC4 and AES encryption (revisions /R 2 - 4 and versions /V 1 - 4 of PDF Encryption).

To open an encrypted PDF document, specify either the user or owner password: `PDF.open( "enc.pdf", :password<ssh!>)`

A document can be encrypted using the `encrypt` method: `$pdf.encrypt( :owner-pass<ssh1>, :user-pass<abc>, :aes )`
   - `:aes` encrypts the document using stronger V4 AES encryption, introduced with PDF 1.6.

Note that it's quite common to leave the user-password blank. This indicates that the document is readable by anyone, but may have restrictions on update, printing or copying of the PDF.

An encrypted PDF can be saved as JSON. It will remain encrypted and passwords may be required, to reopen it.

## Built-in objects

`PDF::COS` also provides a few essential derived classes, that are needed read and write PDF files,
including encryption, object streams and cross reference streams.

*Class* | *Base Class* | *Description*
--- | --- | --- |
PDF | PDF::COS::Dict | document entry point - the trailer dictionary
PDF::COS::Type::Encrypt | PDF::COS::Dict | PDF Encryption/Permissions dictionary
PDF::COS::Type::Info | PDF::COS::Dict | Document Information Dictionary
PDF::COS::Type::ObjStm | PDF::COS::Stream | PDF 1.5+ Object stream (packed indirect objects)
PDF::COS::Type::XRef | PDF::COS::Stream | PDF 1.5+ Cross Reference stream
PDF::COS::TextString | PDF::COS::ByteString | Implements the 'text-string' data-type

## Further Reading

- [PDF Explained](http://shop.oreilly.com/product/0636920021483.do) By John Whitington (120pp) - Offers an excellent overview of the PDF format.
- [PDF 32000-1:2008 1.7](https://opensource.adobe.com/dc-acrobat-sdk-docs/standards/pdfstandards/pdf/PDF32000_2008.pdf) specification - This is the main reference used in the construction of this module.

## See also
- [PDF::Lite](https://pdf-raku.github.io/PDF-Lite-raku) - basic graphics; including images, fonts, text and general graphics
- [PDF::API6](https://pdf-raku.github.io/PDF-API6) - general purpose PDF manipulation (under construction)

