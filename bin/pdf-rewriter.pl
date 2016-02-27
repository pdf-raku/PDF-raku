#!/usr/bin/env perl6
# Simple round trip read and rewrite a PDF
use v6;
use PDF::Reader;

#| rewrite a PDF or FDF and/or convert to/from JSON
sub MAIN (
    Str $file-in,                #| input PDF, FDF or JSON file (.json extension)
    Str $file-out = $file-in,    #| output PDF, FDF or JSON file (.json extension)
    Str  :$password   = '';      #| password for encrypted documents
    Bool :$repair     = False,   #| bypass and repair index. recompute stream lengths. Handy when
                                 #| PDF files have been hand-edited.
    Bool :$rebuild    = False,   #| rebuild object tree (renumber, garbage collect and deduplicate objects)
    Bool :$compress   = False,   #| compress streams
    Bool :$uncompress = False,   #| uncompress streams
    Bool :$struct     = False,   #| require PDF::Struct
    ) {

    if $struct {
	require ::('PDF::Struct')
    }

    die "conflicting arguments: --compress --uncompress"
        if $compress && $uncompress;

    my $reader = PDF::Reader.new;
 
    note "opening {$file-in} ...";
    $reader.open( $file-in, :$repair, :$password );

    if $uncompress || $compress {
        note $compress ?? "compressing ..." !! "uncompressing ...";
        $reader.recompress(:$compress)
    }

    note "building ast ...";
    my $ast = $reader.ast( :$rebuild );
    $reader.save-as($file-out, :$ast); 
    note "done";

}

