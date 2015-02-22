use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Tools::Reader;
use PDF::Tools::Writer;

sub MAIN (Str $input-path, Str $output-path) {

    my $reader = PDF::Tools::Reader.new;
 
    note "opening {$input-path} ...";
    $reader.open( $input-path );
    note "building ast ...";
    my $ast = $reader.ast( :unpack );

    note "writing {$output-path}...";
    my $root-object = $reader.root-object;
    my $pdf-writer = PDF::Tools::Writer.new( :$root-object );
    $output-path.IO.spurt( $pdf-writer.write( $ast ), :enc<latin1> );
    note "done";
}

