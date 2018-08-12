#!/usr/bin/env perl6
# Simple round trip read and rewrite a PDF
use v6;
use PDF::Reader;

#| rewrite a PDF or FDF and/or convert to/from JSON
sub MAIN (
    Str $file-in,                   #= input PDF, FDF or JSON file (.json extension)
    Str $file-out = $file-in,       #= output PDF, FDF or JSON file (.json extension)
    Str  :$password   = '';         #= password for encrypted documents
    Bool :$repair     = False,      #= bypass and repair index. recompute stream lengths. Handy when
                                    #= PDF files have been hand-edited.
    Bool :$rebuild    = False,      #= rebuild object tree (renumber, garbage collect and deduplicate objects)
    Bool :$compress,                #= (un)compress streams
    Bool :$class      = False,      #= require PDF::Class
    ) {

    if $class {
	require ::('PDF::Class')
    }

    my PDF::Reader $reader .= new;

    note "opening {$file-in} ...";
    $reader.open( $file-in, :$repair, :$password );

    with $compress {
        note $_ ?? "compressing ..." !! "uncompressing ...";
        $reader.recompress(:compress($_))
    }

    note "saving ...";
    my $writer = $reader.save-as($file-out, :$rebuild);
    note "done";

}

=begin pod

=head1 NAME

pdf-rewriter.p6 - Rebuild a PDF using the L<PDF> module.

=head1 SYNOPSIS

pdf-rewriter.p6 [options] file.pdf [out.pdf]

Options:
   --password   password for an encrypted PDF
   --repair     repair the input PDF
   --rebuild    rebuild object tree (renumber, garbage collect and deduplicate objects)
   --compress   --/compress compress/uncompress all indirect objects
   --class      load L<PDF::Class> module

=head1 DESCRIPTION

Prints to STDOUT various basic details about the specified PDF
file(s).

=head1 SEE ALSO

L<PDF> (Perl 6)

=cut

=end pod
