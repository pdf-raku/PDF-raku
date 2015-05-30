use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Reader;
use PDF::Writer;

multi sub MAIN (Str $input-path, Str $output-path, Bool :$repair = False, Bool :$compress? is copy, Bool :$uncompress?) {

    die "conflicting arguments: --compress --uncompress"
        if $compress && $uncompress;

    $compress = False if $uncompress;

    my $reader = PDF::Reader.new( );
 
    note "opening {$input-path} ...";
    $reader.open( $input-path, :$repair );

    if $compress.defined {
        # locate and compress/uncompress stream objects
        my $objects = $reader.get-objects;

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
    my $ast = $reader.ast( );

    note "writing {$output-path}...";
    my $root = $reader.root;
    my $input = $reader.input;
    my $pdf-writer = PDF::Writer.new( :$root, :$input );
    $output-path.IO.spurt( $pdf-writer.write( $ast ), :enc<latin1> );
    note "done";
}

