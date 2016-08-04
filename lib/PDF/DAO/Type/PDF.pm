use v6;

use PDF::DAO::Dict;

#| this class represents the top level node in a PDF or FDF document,
#| the trailer dictionary
class PDF::DAO::Type::PDF
    is PDF::DAO::Dict {

    use PDF::Storage::Serializer;
    use PDF::Writer;
    use PDF::DAO::Tie;
    use JSON::Fast;

    # See [PDF 1.7 TABLE 15 Entries in the file trailer dictionary]

    has Int $.Size is entry;                              #| (Required; shall not be an indirect reference) greater than the highest object number defined in the file.

    use PDF::DAO::Type::Encrypt;
    has PDF::DAO::Type::Encrypt $.Encrypt is entry;       #| (Required if document is encrypted; PDF 1.1) The document’s encryption dictionary
    use PDF::DAO::Type::Info;
    has PDF::DAO::Type::Info $.Info is entry(:indirect);  #| (Optional; must be an indirect reference) The document’s information dictionary 
    has Str @.ID is entry(:len(2));                       #| (Required if an Encrypt entry is present; optional otherwise; PDF 1.1) An array of two byte-strings constituting a file identifier

    has Hash $.Root is entry( :indirect );                #| generic document content, as defined by subclassee, e.g.  PDF::DOM or PDF::FDF
    has $.crypt is rw;

    #| open the input file-name or path
    method open($spec, |c) {
        require PDF::Reader;
        my $reader = ::('PDF::Reader').new;
        my $doc = self.new( :$reader );

        $reader.install-trailer( $doc );
        $reader.open($spec, |c);
        $doc.crypt = $reader.crypt
            if $reader.crypt;
        $doc;
    }

    method encrypt( Str :$owner-pass!, Str :$user-pass = '', |c ) {
        require PDF::Storage::Crypt::PDF;
        $!crypt = ::('PDF::Storage::Crypt::PDF').new( :doc(self), :$owner-pass, :$user-pass, |c);
    }

    #| perform an incremental save back to the opened input file, or write
    #| differences to the specified file
    method update(:$compress, IO::Handle :$diffs) {

	self.?cb-init
	    unless self<Root>:exists;
	self<Root>.?cb-finish;

        my $reader = $.reader
            // die "PDF is not associated with an input source";

	die "PDF has not been opened for indexed read."
	    unless $reader.input && $reader.xrefs && $reader.xrefs[0];

	my $type = $reader.type;
	self.generate-id( :$type )
	    unless $diffs;

        my PDF::Storage::Serializer $serializer .= new( :$reader, :$type );
        my Array $body = $serializer.body( :updates, :$compress );
	.crypt-ast('body', $body, :mode<encrypt>)
	    with $!crypt;

        if $diffs && $diffs.path ~~ m:i/'.json' $/ {
            # JSON output to a separate diffs file.
            my %ast = :pdf{ :$body };
            $diffs.print: to-json(%ast);
            $diffs.close;
        }
        else {
            self!incremental-save($body, :$diffs);
        }
    }

    method !incremental-save($body, :$diffs) {
        my Hash $trailer = $body[0]<trailer><dict>;
	my UInt $prev = $trailer<Prev>.value;

        constant Preamble = "\n\n";
        my Numeric $offset = $.reader.input.codes + Preamble.codes;
        my PDF::Writer $writer .= new( :$offset, :$prev );
	my @entries;
        my Str $new-body = $writer.write-body( $body[0], @entries, :$prev, :$trailer );
	my IO::Handle $fh;

	if $diffs {
	    # saving updates elsewhere
	    my Str $path = ~ $diffs.path;

	    die "to file and input PDF are the same: $path"
               if $path eq $.reader.file-name;

	    $fh = $diffs;
	}
	else {
	    # in-place update. merge the updated entries in the index
	    # todo: we should be able to leave the input file open and append to it
	    $prev = $writer.prev;
	    my UInt $size = $writer.size;
	    $.reader.update( :@entries, :$prev, :$size);
	    $.Size = $size;
	    @entries = [];
            with  $.reader.file-name {
                die "Unable to incremetally update a JSON file"
                    if  m:i/'.json' $/;
	        $fh = .IO.open(:a);
            }
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

    multi method save-as(Str $file-name, |c) {
	$.save-as($file-name.IO, |c );
    }

    multi method save-as(IO::Path $iop, Bool :$update, |c) {
	when $iop.path ~~  m:i/'.json' $/ {
	    $iop.spurt( to-json( $.ast(|c) ));
	}
	when $update && $.reader.defined {
	    $.reader.file-name.IO.copy( $iop );
	    $.update( :to($iop.open(:a)), |c);
	}
	default {
	    my $ioh = $iop.open(:w);
	    $.save-as($ioh, |c);
	}
    }

    multi method save-as(IO::Handle $ioh, |c) is default {
        my PDF::Writer $writer .= new;
	$ioh.write: $writer.write( $.ast(|c) ).encode('latin-1')
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

	my Str $hex-string = Buf.new((^256).pick xx 16).decode("latin-1");
	my $new-id = PDF::DAO.coerce: :$hex-string;

	# From [PDF 1.7 Section 14.4 File Indentifiers:
	#   "File identifiers shall be defined by the optional ID entry in a PDF file’s trailer dictionary.
	# The ID entry is optional but should be used. The value of this entry shall be an array of two
	# byte strings. The first byte string shall be a permanent identifier based on the contents of the
	# file at the time it was originally created and shall not change when the file is incrementally
	# updated. The second byte string shall be a changing identifier based on the file’s contents at
	# the time it was last updated. When a file is first written, both identifiers shall be set to the
	# same value. If both identifiers match when a file reference is resolved, it is very likely that
	# the correct and unchanged file has been found. If only the first identifier matches, a different
	# version of the correct file has been found.
	#
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
