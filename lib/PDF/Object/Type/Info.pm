use v6;

use PDF::Object::Tie;
use PDF::Object::Tie::Hash;

# /Info - Trailer entry

role PDF::Object::Type::Info
    does PDF::Object::Tie::Hash {

    use PDF::Object::Name;
    use PDF::Object::DateString;
    use PDF::Object::TextString;

=begin pod

See [PDF 1.7 TABLE 10.2 Entries in the document information dictionary]

=end pod

    has PDF::Object::TextString $.Title is entry;     #| (Optional; PDF 1.1) The document’s title.
    has PDF::Object::TextString $.Author is entry;    #| (Optional) The name of the person who created the document.
    has PDF::Object::TextString $.Subject is entry;   #| (Optional; PDF 1.1) The subject of the document.
    has PDF::Object::TextString $.Keywords is entry;  #| (Optional; PDF 1.1) Keywords associated with the document.
    has PDF::Object::TextString $.Creator is entry;   #| (Optional) If the document was converted to PDF from another format, the name of the application (for example, Adobe FrameMaker®) that created the original document from which it was converted.
    has PDF::Object::TextString $.Producer is entry;  #| (Optional) If the document was converted to PDF from another format, the name of the application (for example, Acrobat Distiller) that converted it to PDF.
    has PDF::Object::DateString $.CreationDate is entry;    #| (Optional) The date and time the document was created, in human-readable form
    has PDF::Object::DateString $.ModDate is entry;         #| (Required if PieceInfo is present in the document catalog; otherwise optional; PDF 1.1) The date and time the document was most recently modified, in human-readable form

    my subset DocTrapping of PDF::Object::Name where 'True' | 'False' | 'Unknown';
    has DocTrapping $.Trapped is entry;         #| A name object indicating whether the document has been modified to include trapping information (see Section 10.10.5, “Trapping Support”):
                                                #| - True:    The document has been fully trapped; no further trapping is needed. (This is the name True, not the boolean value true.)
                                                #| - False:   The document has not yet been trapped; any desired trapping must still be done. (This is the name False, not the boolean value false.)
                                                #| - Unknown: Either it is unknown whether the document has been trapped or it has been partly but not yet fully trapped; some additional trapping may still be needed.

}
