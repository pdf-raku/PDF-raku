use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Tools::Reader;
use PDF::Tools::Writer;

sub MAIN (Str $input-path, Str $output-path) {

    my $reader = PDF::Tools::Reader.new;
 
    note "parsing {$input-path} ...";
    $reader.open( $input-path );

    note "writing {$output-path}...";
    my $pdf-writer = PDF::Tools::Writer.new( );
    $output-path.IO.spurt( $pdf-writer.write( :pdf($reader.ast), :root-obj( $reader.root-obj) ), :enc<latin1> );
}

