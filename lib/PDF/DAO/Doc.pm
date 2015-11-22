use v6;

use PDF::DAO::Dict;

#| this class represents the top level node in a PDF or FDF document,
#| the trailer dictionary
class PDF::DAO::Doc
    is PDF::DAO::Dict {

    use PDF::Storage::Serializer;
    use PDF::Writer;
    use PDF::DAO::Tie;
    use PDF::DAO::Type::Encrypt :PermissionsFlag;

    # See [PDF 1.7 TABLE 3.13 Entries in the file trailer dictionary]

    has Int $.Size is entry;         #| 1 greater than the highest object number used in the file.
                                     #| (Required; must be an indirect reference) The catalog dictionary for the PDF document contained in the file
    has PDF::DAO::Type::Encrypt $.Encrypt is entry;     #| (Required if document is encrypted; PDF 1.1) The document’s encryption dictionary
    use PDF::DAO::Type::Info;
    has PDF::DAO::Type::Info $.Info is entry(:indirect);  #| (Optional; must be an indirect reference) The document’s information dictionary 
    has Str @.ID is entry(:len(2));  #| (Optional, but strongly recommended; PDF 1.1) An array of two byte-strings constituting a file identifier

    has Hash $.Root is entry( :indirect );  #| generic document content, as defined by subclassee, e.g.  PDF::DOM or PDF::FDF

    #| open the input file-name or path
    method open($spec, |c) {
	require ::('PDF::Reader');
        my $reader = ::('PDF::Reader').new;
        my $doc = self.new( :$reader );
        $reader.install-trailer( $doc );
        $reader.open($spec, |c);
        $doc;
    }

    #| perform an incremental save back to the opened input file
    method update(:$compress) {

        my $reader = $.reader
            // die "PDF is not associated with an input source";

	die "PDF has not been opened for indexed read."
	    unless $reader.input && $reader.xrefs && $reader.xrefs[0];

	my $type = $reader.type;
	self!generate-id( :$type );

        # todo we should be able to leave the input file open and append to it
        my Numeric $offset = $reader.input.codes + 1;

        my $serializer = PDF::Storage::Serializer.new( :$reader, :$type );
        my Array $body = $serializer.body( :updates, :$compress );
	$reader.crypt.crypt-ast('body', $body)
	    if $reader.crypt;

	my Hash $trailer = $body[0]<trailer><dict>;
	my UInt $prev = $trailer<Prev>.value;
        my $writer = PDF::Writer.new( :$offset, :$prev );
	my @entries;
        my Str $new-body = "\n" ~ $writer.build-index( $body[0], @entries, :$prev, :$trailer );
	# merge the updated entries in the index
	$prev = $writer.prev;
        my UInt $size = $writer.size;
	$reader.update( :@entries, :$prev, :$size);
	$.Size = $size;
	@entries = [];
        $reader.file-name.IO.open(:a).write( $new-body.encode('latin-1') );
    }

    method save-as(Str $file-name!, |c) {
	my $type = $.reader.?type;
	$type //= $file-name ~~ /:i '.fdf' $/  ?? 'FDF' !! 'PDF';
	self!generate-id( :$type );
	my $serializer = PDF::Storage::Serializer.new;
	my $crypt = self.reader.?crypt;
	$serializer.save-as( $file-name, self, :$type, :$crypt, |c)
    }

    # permissions check, e.g: $doc.permitted( PermissionsFlag::Modify )
    method permitted(UInt $flag --> Bool) {

	return True
	    if self.reader.?is-owner;

	my $perms = self.Encrypt.?P
	    // return True;

	return $perms.flag-is-set( $flag );
    }

    #| Generate a new document ID.  
    method !generate-id(Str :$type) {

	my $obj = $type eq 'FDF' ?? self<Root><FDF> !! self;

	my uint8 @id-chars = (1 .. 16).map: { (^256).pick }
	my Str $hex-string = Buf.new(@id-chars).decode("latin-1");
	my $new-id = PDF::DAO.coerce: :$hex-string;

#	From [PDF 1.7 Section 10.3 File Indentifier
#	File identifiers are defined by the optional ID entry in a PDF file’s trailer dictionary (see Section 3.4.4, “File Trailer”; see also implementation note 162 in Appendix H). The value of this entry is an array of two byte strings. The first byte string is a permanent identifier based on the contents of the file at the time it was originally created and does not change when the file is incrementally updated. The second byte string is a changing identifier based on the file’s contents at the time it was last updated. When a file is first written, both identifiers are set to the same value. If both identifiers match when a file reference is resolved, it is very likely that the correct file has been found. If only the first identifier matches, a different version of the correct file has been found.
# This section also include a weird and expensive solution for generating the ID.
# Contrary to this, just generate a random identifier.

	if $obj<ID> {
	    $obj<ID>[1] = $new-id
	}
	else {
	    $obj<ID> = [ $new-id, $new-id ];
	}
    }
}
