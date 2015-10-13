use v6;

use PDF::DAO::Tie;
use PDF::DAO::Tie::Hash;

# /Encrypt - trailer encryption info

role PDF::DAO::Type::Encrypt
    does PDF::DAO::Tie::Hash {

# See [PDF 1.7 TABLE 3.18 Entries common to all encryption dictionaries]

    use PDF::DAO::Name;
    has PDF::DAO::Name $.Filter is entry(:required);    #| (Required) The name of the preferred security handler for this document. Typically, it is the name of the security handler that was used to encrypt the document. If SubFilter is not present, only this security handler should be used when opening the document. If it is present, consumer applications can use any security handler that implements the format specified by SubFilter.
                                                           #| 'Standard' is the name of the built-in password-based security handler.

   has PDF::DAO::Name $.SubFilter is entry;             #| Optional; PDF 1.3) A name that completely specifies the format and interpretation of the contents of the encryption dictionary. It is needed to allow security handlers other than the one specified by Filter to decrypt the document. If this entry is absent, other security handlers should not be allowed to decrypt the document.
                                                           #| Note: This entry was introduced in PDF 1.3 to support the use of public-key cryptography in PDF files; however, it was not incorporated into the PDF Reference until the fourth edition (PDF 1.5).

    has UInt $.V is entry;                                 #| (Optional but strongly recommended) A code specifying the algorithm to be used in encrypting and decrypting the document:
                                                           #|   0: An algorithm that is undocumented and no longer supported, and whose use is strongly discouraged.
                                                           #|   1: Algorithm 3.1 on [PDF 1.7 page 119], with an encryption key length of 40 bits; see below.
                                                           #|   2: (PDF 1.4) Algorithm 3.1, but permitting encryption key lengths greater than 40 bits.
                                                           #|   3: (PDF 1.4) An unpublished algorithm that permits encryption key lengths ranging from 40 to 128 bits.
                                                           #|   4: (PDF 1.5) The security handler defines the use of encryption and decryption in the document, using the rules specified by the CF, StmF, and StrF entries.
                                                           #| The default value if this entry is omitted is 0, but a value of 1 or greater is strongly recommended

    has UInt $.Length is entry;                            #| (Optional; PDF 1.4; only if V is 2 or 3) The length of the encryption key, in bits. The value must be a multiple of 8, in the range 40 to 128. Default value: 40.

    has Hash $.CF is entry;                                #| (Optional; meaningful only when the value of V is 4; PDF 1.5) A dictionary whose keys are crypt filter names and whose values are the corresponding crypt filter dictionaries (see Table 3.22). Every crypt filter used in the document must have an entry in this dictionary, except for the standard crypt filter names

    has PDF::DAO::Name $.StmF is entry;                 #| (Optional; meaningful only when the value of V is 4; PDF 1.5) The name of the crypt filter that is used by default when decrypting streams. The name must be a key in the CF dictionary or a standard crypt filter name specified in Table 3.23. All streams in the document, except for cross-reference streams (see Section 3.4.7, “Cross-Reference Streams”) or streams that have a Crypt entry in their Filter array (see Table 3.5), are decrypted by the security handler, using this crypt filter.
                                                           #| Default value: Identity.

    has PDF::DAO::Name $.StrF is entry;                 #| (Optional; meaningful only when the value of V is 4; PDF 1.5) The name of the crypt filter that is used when decrypting all strings in the document. The name must be a key in the CF dictionary or a standard crypt filter name specified in Table 3.23.
                                                           #| Default value: Identity.

    has PDF::DAO::Name $.EFF is entry;                  #| (Optional; meaningful only when the value of V is 4; PDF 1.6) The name of the crypt filter that should be used by default when encrypting embedded file streams; it must correspond to a key in the CF dictionary or a standard crypt filter name specified in Table 3.23.
                                                           #| This entry is provided by the security handler. Applications should respect this value when encrypting embedded files, except for embedded file streams that have their own crypt filter specifier. If this entry is not present, and the embedded file stream does not contain a crypt filter specifier, the stream should be encrypted using the default stream crypt filter specified by StmF.

   # See [PDF 1.7 TABLE 3.19 Additional encryption dictionary entries for the standard security handler]

    has UInt $.R is entry;      #| (Required) A number specifying which revision of the standard security handler should be used to interpret this dictionary:
                                #| • 2 if the document is encrypted with a V value less than 2 (see Table 3.18) and does not have any of the access permissions set (by means of the P entry, below) that are designated “Revision 3 or greater” in Table 3.20
                                #| • 3 if the document is encrypted with a V value of 2 or 3, or has any “Revision 3 or greater” access permissions set
                                #| • 4 if the document is encrypted with a V value of 4


    has Str $.O is entry;       #| (Required) A 32-byte string, based on both the owner and user passwords, that is used in computing the encryption key and in determining whether a valid owner password was entered.

    has Str $.U is entry;       #| (Required) A 32-byte string, based on the user password, that is used in determining whether to prompt the user for a password and, if so, whether a valid user or owner password was entered.

    my enum PermissionsFlag is export(:PermissionsFlag) « :Print(3) :Modify(4) :Copy(5) :Add(6) :Fill(9)
							  :Extract(10) :Assemble(11) :Distribute(12) »;

    has Int $.P is entry;      #| (Required) A set of flags specifying which operations are permitted when the document is opened with user access

    has Bool $.EncryptMetadata; #| (Optional; meaningful only when the value of V is 4; PDF 1.5) Indicates whether the document-level metadata stream (see Section 10.2.2, “Metadata Streams”) is to be encrypted. Applications should respect this value.
                                #| Default value: true.

}
