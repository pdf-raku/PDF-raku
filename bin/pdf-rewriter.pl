#!/usr/bin/env perl6
use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Reader;
use PDF::Writer;

#| rewrite a PDF or FDF  and/or convert to/from JSON
sub MAIN (
    Str $pdf-or-json-file-in,    # input PDF, FDF or JSON file (.json extension)
    Str $pdf-or-json-file-out,   # output PDF, FDF or JSON file (.json extension)
    Bool :$repair = False,       # bypass and repair index. recompute stream lengths. Handy when
                                 # when PDF files have been hand-edited.
    Bool :$rebuild    = False,   # rebuild object tree (renumber, garbage collect and deduplicate objects)
    Bool :$compress   = False,   # uncompress streams
    Bool :$uncompress = False,   # compress streams
    Str  :$password = '';        # owner password for encrypted documents
    Bool :$dom = False,          # require PDF::DOM
    ) {

    if $dom {
        require ::('PDF::DOM')
    }

    die "conflicting arguments: --compress --uncompress"
        if $compress && $uncompress;

    my $reader = PDF::Reader.new;
 
    note "opening {$pdf-or-json-file-in} ...";
    $reader.open( $pdf-or-json-file-in, :$repair, :$password );

    if $uncompress || $compress {
        note $compress ?? "compressing ..." !! "uncompressing ...";
        $reader.recompress(:$compress)
    }

    note "building ast ...";
    my $ast = $reader.ast( :$rebuild );
    $reader.save-as($pdf-or-json-file-out, :$ast); 
    note "done";

}

