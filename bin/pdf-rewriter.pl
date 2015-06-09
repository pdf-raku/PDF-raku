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
    Bool :$dom = False,          # require PDF::DOM
    ) {

    if $dom {
        require ::('PDF::DOM')
    }

    die "conflicting arguments: --compress --uncompress"
        if $compress && $uncompress;

    my $reader = PDF::Reader.new( );
 
    note "opening {$pdf-or-json-file-in} ...";
    $reader.open( $pdf-or-json-file-in, :$repair );

    note "Document is encrypted."
        if $reader.trailer-dict<Encrypt>:exists;

    if $compress || $uncompress {
        # locate and compress/uncompress stream objects
        my $objects = $reader.get-objects;
        note $compress ?? "compressing ..." !! "uncompressing ...";

        for $objects.list {
            my ($type, $ind-obj) = .kv;
            next unless $type eq 'ind-obj';
            my ($obj-type, $obj-raw) = $ind-obj[2].kv;
            if $obj-type eq 'stream' {
                my $is-compressed = $obj-raw<dict><Filter>:exists;
                next if $compress == $is-compressed;
                my $obj-num = $ind-obj[0];
                my $gen-num = $ind-obj[1];
                # fully stantiate object and adjust compression
                my $object = $reader.ind-obj( $obj-num, $gen-num).object;
                $compress ?? $object.compress !! $object.uncompress;
            }
        }
    }
    note "building ast ...";
    my $ast = $reader.ast( :$rebuild );
    $reader.write($pdf-or-json-file-out, :$ast); 
    note "done";

}

