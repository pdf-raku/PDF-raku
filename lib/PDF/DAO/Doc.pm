use v6;

use PDF::DAO::Dict;

#| this class represents the top level node in a PDF or FDF document,
#| the trailer dictionary
class PDF::DAO::Doc
    is PDF::DAO::Dict {

    use PDF::Storage::Serializer;
    use PDF::Storage::Crypt;
    use PDF::Reader;
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
    has PDF::Storage::Crypt $.crypt is rw;

    #| open the input file-name or path
    method open($spec, |c) {
        my PDF::Reader $reader .= new;
        my $doc = self.new( :$reader );

        $reader.install-trailer( $doc );
        $reader.open($spec, |c);
        $doc.crypt = $reader.crypt
            if $reader.crypt;
        $doc;
    }

    method encrypt( Str :$owner-pass!, Str :$user-pass = '', |c ) {
        # only RC4 ATM
        require ::('PDF::Storage::Crypt::RC4');
        $!crypt = ::('PDF::Storage::Crypt::RC4').new( :doc(self), :$owner-pass, :$user-pass, |c);
    }

    #| perform an incremental save back to the opened input file, or to the
    #| specified annex file
    method update(:$compress, Str :$annex) {

	self.?cb-init
	    unless self<Root>:exists;
	self<Root>.?cb-finish;

        my $reader = $.reader
            // die "PDF is not associated with an input source";

	die "PDF has not been opened for indexed read."
	    unless $reader.input && $reader.xrefs && $reader.xrefs[0];

	die "annex file and input PDF are the same: $annex"
	    if $annex && $annex eq $reader.file-name;

        die "JSON annex files are NYI"
	    if $annex && $annex ~~ m:i/'.json' $/;

	my $type = $reader.type;
	self.generate-id( :$type )
	    unless $annex;

        my PDF::Storage::Serializer $serializer .= new( :$reader, :$type );
        my Array $body = $serializer.body( :updates, :$compress );
	$!crypt.crypt-ast('body', $body)
	    if $!crypt;

	my Hash $trailer = $body[0]<trailer><dict>;
	my UInt $prev = $trailer<Prev>.value;

        constant Preamble = "\n\n";
        my Numeric $offset = $reader.input.codes + Preamble.codes;
        my PDF::Writer $writer .= new( :$offset, :$prev );
	my @entries;
        my Str $new-body = $writer.write-body( $body[0], @entries, :$prev, :$trailer );

	my $fh;
	if $annex {
	    # saving updates as a PDF annex fragment elsewhere.
	    $fh = $annex.IO.open(:w)
	}
	else {
	    # in-place update. merge the updated entries in the index
	    # todo: we should be able to leave the input file open and append to it
	    $prev = $writer.prev;
	    my UInt $size = $writer.size;
	    $reader.update( :@entries, :$prev, :$size);
	    $.Size = $size;
	    @entries = [];
	    $fh = $reader.file-name.IO.open(:a);
	}

        $fh.write: Preamble.encode('latin-1');
        $fh.write: $new-body.encode('latin-1');
        $fh.close;
    }

    method ast(|c) {
	die "no top-level Root entry"
	    unless self<Root>:exists;
	
	self<Root>.?cb-finish;

	my $type = $.reader.?type;
	$type //= self<Root><FDF>:exists ?? 'FDF' !! 'PDF';
	self.generate-id( :$type );
	my PDF::Storage::Serializer $serializer .= new;
	$serializer.ast( self, :$type, :$!crypt, |c);
    }

    method save-as($target! where Str | IO::Handle | IO::Path, |c) {

	multi sub save-to(Str $file-name where m:i/'.json' $/, Pair $ast) {
            use JSON::Fast;
	    $file-name.IO.spurt( to-json( $ast ))
	}

	multi sub save-to(Str $file-name, Pair $ast) {
	    save-to($file-name.IO, $ast);
	}

	multi sub save-to(IO::Path $iop, Pair $ast) {
	    save-to($iop.open(:w), $ast);
	}

	multi sub save-to(IO::Handle $ioh, Pair $ast) is default {
            my PDF::Writer $writer .= new;
	    $ioh.write: $writer.write( $ast ).encode('latin-1')
	}

	save-to($target, $.ast(|c) );
    }

    #| stringify to the serialized PDF
    method Str {
        my PDF::Writer $writer .= new;
	$writer.write( $.ast )
    }

    # permissions check, e.g: $doc.permitted( PermissionsFlag::Modify )
    method permitted(UInt $flag --> Bool) {

	return True
	    if $!crypt.?is-owner;

	my $perms = self.Encrypt.?P
	    // return True;

	return $perms.flag-is-set( $flag );
    }

    #| Generate a new document ID.  
    method generate-id(Str :$type = 'PDF') {

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
