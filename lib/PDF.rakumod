use v6;

use PDF::COS::Dict;

#| this class represents the top level node in a PDF or FDF document,
#| the trailer dictionary
class PDF:ver<0.5.19>
    is PDF::COS::Dict {

    use PDF::COS;
    use PDF::IO::Serializer;
    use PDF::IO::Reader;
    use PDF::IO::Writer;
    use PDF::COS::Tie;
    use JSON::Fast;

    # use ISO_32000::Table_15-Entries_in_the_file_trailer_dictionary;
    # also does ISO_32000::Table_15-Entries_in_the_file_trailer_dictionary;

    has Int $.Size is entry;                              #| (Required; shall not be an indirect reference) greater than the highest object number defined in the file.

    use PDF::COS::Type::Encrypt;
    has PDF::COS::Type::Encrypt $.Encrypt is entry;       #| (Required if document is encrypted; PDF 1.1) The document’s encryption dictionary

    use PDF::COS::Type::Info;
    has PDF::COS::Type::Info $.Info is entry(:indirect);  #| (Optional; must be an indirect reference) The document’s information dictionary
    has Str $.id;
    has Str @.ID is entry(:len(2));                       #| (Required if an Encrypt entry is present; optional otherwise; PDF 1.1) An array
                                                          #| of two byte-strings constituting a file identifier

    has Hash $.Root is entry(:indirect);                  #| generic document root, as defined by subclassee, e.g.  PDF::Class, FDF
    has $.crypt is rw;
    has $!flush = False;

    has UInt $.Prev is entry; 

    submethod TWEAK(:$file, |c) is hidden-from-backtrace {
        self!open-file($_, |c) with $file;
    }

    method id is rw {
        $!id //= do {
            # From [PDF 32000 Section 14.4 File Identifiers:
            #   "File identifiers shall be defined by the optional ID entry in a PDF file’s trailer dictionary.
            # The ID entry is optional but should be used. The value of this entry shall be an array of two
            # byte strings. The first byte string shall be a permanent identifier based on the contents of the
            # file at the time it was originally created and shall not change when the file is incrementally
            # updated. The second byte string shall be a changing identifier based on the file’s contents at
            # the time it was last updated. When a file is first written, both identifiers shall be set to the
            # same value. If both identifiers match when a file reference is resolved, it is very likely that
            # the correct and unchanged file has been found. If only the first identifier matches, a different
            # version of the correct file has been found."
            #
            # This section also includes a weird and expensive solution for generating the ID.
            # Contrary to this, just generate a random identifier.

            my Str $hex-string = Buf.new((^256).pick xx 16).decode("latin-1");
            PDF::COS.coerce: :$hex-string;
        }
    }

    #| open the input file-name or path
    method open($spec, |c) is hidden-from-backtrace {
        self.new!open-file: $spec, |c;
    }
    method !open-file(::?CLASS:D: $spec, Str :$type, |c) is hidden-from-backtrace {
        my PDF::IO::Reader $reader .= new: :trailer(self);
        self.reader = $reader;
        $reader.open($spec, |c);
        with $type {
            die "PDF file has wrong type: " ~ $reader.type
                unless $reader.type eq $_;
        }
        self.crypt = $_
            with $reader.crypt;
        self;
    }

    method encrypt(PDF:D $doc: Str :$owner-pass!, Str :$user-pass = '', :$EncryptMetadata = True, |c ) {

        die '.encrypt(:!EncryptMetadata, ...) is not yet supported'
            unless $EncryptMetadata;

        with $.reader {
            with .crypt {
                # the input document is already encrypted
                die "PDF is already encrypted. Need to be owner to re-encrypt"
                    unless .is-owner;
            }
        }

        $doc<Encrypt>:delete;
        $!flush = True;
        $!crypt = PDF::COS.required('PDF::IO::Crypt::PDF').new: :$doc, :$owner-pass, :$user-pass, |c;
    }

    method !is-indexed {
        with $.reader {
            ? (.input && .xrefs && .xrefs[0]);
        }
        else {
            False;
        }
    }

    method cb-finish {
	self.?cb-init
	    unless self<Root>:exists;
	self<Root>.?cb-finish;
    }
    #| perform an incremental save back to the opened input file, or write
    #| differences to the specified file
    method update(IO::Handle :$diffs, |c) {

        die "Newly encrypted PDF must be saved in full"
            if $!flush;

	die "PDF has not been opened for indexed read."
	    unless self!is-indexed;

        self.cb-finish;

	my $type = $.reader.type;
	self!set-id( :$type );

        my PDF::IO::Serializer $serializer .= new( :$.reader, :$type );
        my Array $body = $serializer.body( :updates, |c );
	.crypt-ast('body', $body, :mode<encrypt>)
	    with $!crypt;

        if $diffs && $diffs.path ~~ m:i/'.json' $/ {
            # JSON output to a separate diffs file.
            my %ast = :cos{ :$body };
            $diffs.print: to-json(%ast);
            $diffs.close;
        }
        elsif ! +$body[0]<objects> {
            # no updates that need saving
        }
        else {
            my IO::Handle $fh;
            my Bool $in-place = False;

            do with $diffs {
                # Seperate saving of updates
                $fh = $_ unless .path ~~ $.reader.file-name;

            }
            $fh //= do {
                $in-place = True;
                # Append update to the input PDF
                given $.reader.file-name {
                    die "Incremental update of JSON files is not supported"
                        if  m:i/'.json' $/;
                    .IO.open(:a, :bin);
                }
            }

            self!incremental-save($fh, $body[0], :$diffs, :$in-place);
        }
    }

    method !incremental-save(IO::Handle:D $fh, Hash $body, :$diffs, :$in-place) {
        my constant Pad = "\n\n".encode('latin-1');

        my Hash $trailer = $body<trailer><dict>;
	my UInt $prev = $trailer<Prev>;
        my $size = $.reader.size;
        my $compat = $.reader.compat;
        my PDF::IO::Writer $writer .= new: :$prev, :$size, :$compat;
        my $offset = $.reader.input.codes + Pad.bytes;

        $fh.write: Pad;
        $writer.stream-body: $fh, $body, my @entries, :$offset;

        if $in-place {
	    # Input PDF updated; merge the updated entries in the index
	    $prev = $writer.prev;
	    my UInt $size = $writer.size;
	    $.reader.update-index( :@entries, :$prev, :$size);
	    $.Size = $size;
	    @entries = [];
	}

        $fh.close;
    }

    method ast(|c) {
        self.cb-finish;
	my $type = $.reader.?type
            // self.?type
            // (self<Root><FDF>.defined ?? 'FDF' !! 'PDF');

	self!set-id( :$type );
	my PDF::IO::Serializer $serializer .= new;
	$serializer.ast: self, :$type, :$!crypt, |c;
    }

    method !ast-writer(|c) {
        my $eager := ! $!flush;
        my $ast = $.ast: :$eager, |c;
        PDF::IO::Writer.new: :$ast;
    }

    multi method save-as(IO::Handle $ioh, |c) {
        self!ast-writer(|c).stream-cos: $ioh;
    }

    multi method save-as(IO() $iop,
                     Bool :$preserve = True,
                     Bool :$rebuild = False,
                     Bool :$stream,
                     |c) {
	when $iop.extension.lc eq 'json' {
            # save as JSON
	    $iop.spurt: to-json( $.ast(|c) );
	}
        when $preserve && !$rebuild && !$!flush && self!is-indexed && $.reader.file-name.defined {
            # copy the input PDF, then incrementally update it. This is faster
            # and plays better with digitally signed documents.
            my $diffs = $iop.open(:a, :bin);
            given $.reader.file-name {
	        .IO.copy( $iop )
                    unless $iop.path eq $_;
            }
	    $.update( :$diffs, |c);
	}
	default {
            # full save
            if $stream {
                # wont work for in-place update
	        my $ioh = $iop.open(:w, :bin);
	        self!ast-writer(|c).stream-cos($ioh);
                $ioh.close;
            }
            else {
                $iop.spurt: self!ast-writer(|c).Blob;
            }
	}
    }

    #| stringify to the serialized PDF
    method Str(|c) {
	self!ast-writer(|c).write;
    }

    # permissions check, e.g: $doc.permitted( PermissionsFlag::Modify )
    method permitted(UInt $flag --> Bool) is DEPRECATED('please use PDF::Class.permitted') {

        return True
            if $!crypt.?is-owner;

        with self.Encrypt {
            .permitted($flag);
        }
        else {
            True;
        }
    }

    method Blob(|c) returns Blob {
	self.Str(|c).encode: "latin-1";
    }

    #| Initialize or update the document id
    method !set-id(Str :$type = 'PDF') {
        my $obj = $type eq 'FDF' ?? self<Root><FDF> !! self;
	with $obj<ID> {
	    .[1] = $.id; # Update modification ID
	}
	else {
	    $_ = [ $.id xx 2 ]; # Initialize creation and modification IDs
	}
        $!id = Nil;
    }
}
