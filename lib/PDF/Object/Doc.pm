use v6;

use PDF::Object::Dict;
use PDF::Object::Tie::Hash;

#| this class represent the top level node in a PDF document,
#| the trailer dictionary
class PDF::Object::Doc
    is PDF::Object::Dict
    does PDF::Object::Tie::Hash {

    use PDF::Storage::Serializer;
    use PDF::Writer;
    use PDF::Object::Tie;
    use PDF::Object::Type::Info;

    has Int $.Size is entry;         #| 1 greater than the highest object number used in the file.
                                     #| (Required; must be an indirect reference) The catalog dictionary for the PDF document contained in the file
    has Hash $.Encrypt is entry;     #| (Required if document is encrypted; PDF 1.1) The document’s encryption dictionary
    has PDF::Object::Type::Info $.Info is entry(:indirect);  #| (Optional; must be an indirect reference) The document’s information dictionary 
    has Array $.ID is entry;         #| (Optional, but strongly recommended; PDF 1.1) An array of two byte-strings constituting a file identifier

    has Hash $.Root is entry( :indirect );

    #| open an input file
    use PDF::Storage::Input;
    multi method open(PDF::Storage::Input $input) { self!open($input) }
    multi method open(Str $file-name) is default  { self!open($file-name) }

    method !open($spec) {
	require ::('PDF::Reader');
        my $reader = ::('PDF::Reader').new;
        my $doc = self.new;
        $reader.install-trailer( $doc );
        $reader.open($spec);
        $doc;
    }

    #| perform an incremental save back to the opened input file
    method update(:$compress) {

        my $reader = $.reader
            // die "pdf is not associated with an input source";

        die "pdf reader is defunct"
            if $reader.defunct;
 
        # todo we should be able to leave the input file open and append to it
        my Numeric $offset = $reader.input.chars + 1;

        my $serializer = PDF::Storage::Serializer.new;
        my Hash $body = $serializer.body( $reader, :updates, :$compress );
        my Int $prev = $body<trailer><dict><Prev>.value;
        my $writer = PDF::Writer.new( :$offset, :$prev );
        my Str $new-body = "\n" ~ $writer.write( :$body );
        $reader.input.?close;
        $reader.input = Any;
        $reader.defunct = True;
        $reader.file-name.IO.open(:a).write( $new-body.encode('latin-1') );
    }

    #| use the reader when available.
    multi method save-as(Str $file-name! where {$.reader.defined && !$.reader.defunct},
                         Numeric :$version?,
                         Bool :$rebuild = False,
                         :$compress,
        ) {
        $.reader.recompress( :$compress ) if $compress.defined;
        $.reader.version = $version if $version.defined;
        $.reader.save-as($file-name, :$rebuild);
    }

    #| do a full save to the named file
    multi method save-as(Str $file-name!,
                         Numeric :$version=1.3,
                         :$type='PDF',     #| e.g. 'PDF', 'FDF;
                         :$compress = False,
        ) {
	my $serializer = PDF::Storage::Serializer.new;
	$serializer.save-as( $file-name, self, :$type, :$version, :$compress);
    }
}
