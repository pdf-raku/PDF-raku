use v6;

use PDF::Object::Tie;
use PDF::Object::Tie::Hash;

# AcroForm role - see PDF::DOM::Type::Catalog - /AcroForm entry

role PDF::Object::Type::Info
    does PDF::Object::Tie::Hash {

    use PDF::Object::DateString;

=begin pod

See [PDF 1.7 TABLE 10.2 Entries in the document information dictionary]

=end pod

    has Str $.Title is entry;     #| (Optional; PDF 1.1) The document’s title.
    has Str $.Author is entry;    #| (Optional) The name of the person who created the document.
    has Str $.Subject is entry;   #| (Optional; PDF 1.1) The subject of the document.
    has Str $.Keywords is entry;  #| (Optional; PDF 1.1) Keywords associated with the document.
    has Str $.Creator is entry;   #| (Optional) If the document was converted to PDF from another format, the name of the application (for example, Adobe FrameMaker®) that created the original document from which it was converted.
    has Str $.Producer is entry;  #| (Optional) If the document was converted to PDF from another format, the name of the application (for example, Acrobat Distiller) that converted it to PDF.
    has PDF::Object::DateString $.CreationDate is entry( :coerce );    #| (Optional) The date and time the document was created, in human-readable form
    has PDF::Object::DateString $.ModDate is entry( :coerce );         #| (Required if PieceInfo is present in the document catalog; otherwise optional; PDF 1.1) The date and time the document was most recently modified, in human-readable form

}
