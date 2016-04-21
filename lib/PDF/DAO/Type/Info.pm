use v6;

use PDF::DAO::Tie;
use PDF::DAO::Tie::Hash;

# /Info - Trailer entry

role PDF::DAO::Type::Info
    does PDF::DAO::Tie::Hash {

    use PDF::DAO::Name;
    use PDF::DAO::DateString;
    use PDF::DAO::TextString;

=begin pod

See [PDF 1.7 TABLE 317 Entries in the document information dictionary]

=end pod

    has PDF::DAO::TextString $.Title is entry;     #| (Optional; PDF 1.1) The document’s title.
    has PDF::DAO::TextString $.Author is entry;    #| (Optional) The name of the person who created the document.
    has PDF::DAO::TextString $.Subject is entry;   #| (Optional; PDF 1.1) The subject of the document.
    has PDF::DAO::TextString $.Keywords is entry;  #| (Optional; PDF 1.1) Keywords associated with the document.
    has PDF::DAO::TextString $.Creator is entry;   #| (Optional) If the document was converted to PDF from another format, the name of the application (for example, Adobe FrameMaker®) that created the original document from which it was converted.
    has PDF::DAO::TextString $.Producer is entry;  #| (Optional) If the document was converted to PDF from another format, the name of the application (for example, Acrobat Distiller) that converted it to PDF.
    has PDF::DAO::DateString $.CreationDate is entry;    #| (Optional) The date and time the document was created, in human-readable form
    has PDF::DAO::DateString $.ModDate is entry;         #| (Required if PieceInfo is present in the document catalog; otherwise optional; PDF 1.1) The date and time the document was most recently modified, in human-readable form

    my subset DocTrapping of PDF::DAO::Name where 'True' | 'False' | 'Unknown';
    has DocTrapping $.Trapped is entry;         #| A name object indicating whether the document has been modified to include trapping information (see Section 10.10.5, “Trapping Support”):
                                                #| - True:    The document has been fully trapped; no further trapping is needed. (This is the name True, not the boolean value true.)
                                                #| - False:   The document has not yet been trapped; any desired trapping must still be done. (This is the name False, not the boolean value false.)
                                                #| - Unknown: Either it is unknown whether the document has been trapped or it has been partly but not yet fully trapped; some additional trapping may still be needed.

}
