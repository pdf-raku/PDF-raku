use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Reader;
use PDF::Writer;

sub MAIN (Str $input-path, Str $output-path) {

    my $reader = PDF::Reader.new;
 
    note "opening {$input-path} ...";
    $reader.open( $input-path );
    note "building ast ...";
    my $ast = $reader.ast( );

    note "writing {$output-path}...";
    my $root = $reader.root;
    my $pdf-writer = PDF::Writer.new( :$root );
    $output-path.IO.spurt( $pdf-writer.write( $ast ), :enc<latin1> );
    note "done";
}

