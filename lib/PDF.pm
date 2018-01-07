use v6;

use PDF::DAO::Dict;

#| this class represents the top level node in a PDF or FDF document,
#| the trailer dictionary
class PDF:ver<0.2.7>
    is PDF::DAO::Dict {

    use PDF::IO::Serializer;
    use PDF::Reader;
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

    has Hash $.Root is entry( :indirect );                #| generic document content, as defined by subclassee, e.g.  PDF::Catalog, PDF::FDF
    has $.crypt is rw;

    #| open the input file-name or path
    method open($spec, |c) {
        my PDF::Reader $reader .= new;
        my \doc = self.new: :$reader;

        $reader.trailer = doc;
        $reader.open($spec, |c);
        doc.crypt = $_
            with $reader.crypt;
        doc;
    }

    method encrypt( Str :$owner-pass!, Str :$user-pass = '', |c ) {
        $!crypt = (require PDF::IO::Crypt::PDF).new( :doc(self), :$owner-pass, :$user-pass, |c);
    }

    #| perform an incremental save back to the opened input file, or write
    #| differences to the specified file
    method update(IO::Handle :$diffs, |c) {

	self.?cb-init
	    unless self<Root>:exists;
	self<Root>.?cb-finish;

        my $reader = $.reader
            // die "PDF is not associated with an input source";

	die "PDF has not been opened for indexed read."
	    unless $reader.input && $reader.xrefs && $reader.xrefs[0];

	my $type = $reader.type;
	self!generate-id( :$type );

        my PDF::IO::Serializer $serializer .= new( :$reader, :$type );
        my Array $body = $serializer.body( :updates, |c );
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
        my Str $new-body = $writer.write-body( $body[0], my @entries, :$prev, :$trailer );
	my IO::Handle $fh = do with $diffs {
	    # saving updates elsewhere
	    my Str $path = ~ .path;

	    die "to file and input PDF are the same: $path"
               if $path eq $.reader.file-name;

	    $_;
	}
	else {
	    # in-place update. merge the updated entries in the index
	    # todo: we should be able to leave the input file open and append to it
	    $prev = $writer.prev;
	    my UInt $size = $writer.size;
	    $.reader.update( :@entries, :$prev, :$size);
	    $.Size = $size;
	    @entries = [];
            given $.reader.file-name {
                die "Unable to incrementally update a JSON file"
                    if  m:i/'.json' $/;
	        .IO.open(:a, :bin);
            }
	}

        $fh.write: Preamble.encode('latin-1');
        $fh.write: $new-body.encode('latin-1');
        $fh.close;
    }

    method ast(|c) {
	my $type = $.reader.?type;
	with self<Root> {
	    .?cb-finish;
	    $type //= .<FDF> ?? 'FDF' !! 'PDF';
        }
        else {
	    die "no top-level Root entry"
        }

	self!generate-id( :$type );
	my PDF::IO::Serializer $serializer .= new;
	$serializer.ast( self, :$type, :$!crypt, |c);
    }

    multi method save-as(Str $file-name, |c) {
	$.save-as($file-name.IO, |c );
    }

    multi method save-as(IO::Path $iop, Bool :$preserve, |c) {
	when $iop.extension.lc eq 'json' {
	    $iop.spurt( to-json( $.ast(|c) ));
	}
	when $preserve && $.reader.defined {
	    $.reader.file-name.IO.copy( $iop );
	    $.update( :to($iop.open(:a, :bin)), |c);
	}
	default {
	    my $ioh = $iop.open(:w, :bin);
	    $.save-as($ioh, |c);
	}
    }

    multi method save-as(IO::Handle $ioh, |c) is default {
        my $ast = $.ast(|c);
        my PDF::Writer $writer .= new: :$ast;
        $ioh.write: $writer.Blob;
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
    method !generate-id(Str :$type = 'PDF') {

	# From [PDF 1.7 Section 14.4 File Identifiers:
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
	# This section also includes a weird and expensive solution for generating the ID.
	# Contrary to this, just generate a random identifier.

	my $obj = $type eq 'FDF' ?? self<Root><FDF> !! self;
	my Str $hex-string = Buf.new((^256).pick xx 16).decode("latin-1");
	my \new-id = PDF::DAO.coerce: :$hex-string;

	with $obj<ID> {
	    .[1] = new-id
	}
	else {
	    $_ = [ new-id, new-id ];
	}
    }
}
