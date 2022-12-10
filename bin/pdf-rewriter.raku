#!/usr/bin/env raku
# Simple round trip read and rewrite a PDF
use v6;
use PDF::IO::Reader;
use PDF;

#| rewrite a PDF or FDF and/or convert to/from JSON
sub MAIN(
    Str $file-in,               # input PDF, FDF or JSON file
    Str $file-out = $file-in,   # output PDF, FDF or JSON file
    Str  :$password  = '';      # password for encrypted documents
    Bool :$repair    = False,   # bypass and repair index. recompute stream lengths. Handy when
                                # PDF files have been hand-edited.
    Bool :$rebuild is copy,     # rebuild object tree (renumber, garbage collect and deduplicate objects)
    Bool :$compress is copy,    # compress streams
    Bool :$uncompress,          # uncompress streams
    Str  :$class is copy,       # load a class (PDF::Class, PDF::Lite, PDF::API6)
    Bool :$render,              # render and reformat content (needs PDF::Lite or PDF::Class)
    Bool :$decrypt is copy,     # decrypt
    Bool :$stream,              # write early and progressively
    Rat :$compat,               # PDF compatibility level (1.4 or 1.5)
    ) {

    die "Can't stream a PDF file to itself"
        if $stream && $file-out eq $file-in;

    $compress //= False if $uncompress;
    $rebuild  //= True  if $decrypt || $render;
    $class    //= 'PDF::Lite' if $render;

    CATCH {
        when X::PDF { note .message; exit 1; }
    }

    my PDF $pdf;
    my PDF::IO::Reader $reader;

    if $class {
	$pdf = (require ::($class));
    }

    note "opening {$file-in} ...";
    if $render {
        $pdf .= open( $file-in, :$repair, :$password );
        $reader = $pdf.reader;
    }
    else {
        $reader .= new.open( $file-in, :$repair, :$password );
    }

    $reader.compat = $_ with $compat;

    if $decrypt {
        with $reader.crypt {
            die "only the owner of this PDF can decrypt it"
                unless .is-owner;
        }
        else {
            $decrypt = False; # not encrypted
        }
    }

    with $compress {
        note $_ ?? "compressing ..." !! "uncompressing ...";
        $reader.recompress(:compress($_));
    }
    elsif $decrypt {
        # ensure all objects have been loaded and decrypted
        $reader.get-objects;
    }

    if $decrypt {
        $reader.crypt = Nil;
        .crypt = Nil with $pdf;
        $reader.trailer<Encrypt>:delete;
    }

    if $render {
        my $n = $pdf.page-count;
        for 1 .. $n {
            $*ERR.print: "rendering... $_/$n\r";
            with $pdf.page($_) {
                .render;
                .<Contents><Filter>:delete
                    unless $compress;
            }
        }
        $*ERR.say: '';
    }

    note "saving ...";
    ($pdf // $reader).save-as($file-out, :$stream, :$rebuild);
    note "done";

}

=begin pod

=head1 NAME

pdf-rewriter.raku - Rebuild a PDF using L<PDF> modules.

=head1 SYNOPSIS

    pdf-rewriter.raku [options] file.pdf [out.pdf]
    pdf-rewriter.raku [options] file.pdf [out.json] # convert to json
    pdf-rewriter.raku [options] file.json [out.pdf] # convert from json

=head2 Options

   --password    password for an encrypted PDF
   --repair      repair the input PDF
   --rebuild     rebuild object tree (renumber, garbage collect and deduplicate objects)
   --compress    compress streams
   --uncompress  uncompress streams, where possible
   --class=name  load class (PDF::Lite, PDF::Class, PDF::API6)
   --render      render and reformat content (needs PDF::Class or PDF::Lite)
   --decrypt     remove encryption
   --stream      write progressively and early

=head1 DESCRIPTION

Rewrites the specified PDF document.

Input and output files may be either PDF or JSON.

=head1 SEE ALSO

L<PDF> (Perl 6)

=cut

=end pod
