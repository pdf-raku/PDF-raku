use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Tools::Reader;
use PDF::Tools::Writer;

sub MAIN (Str $input, Str $output) {

    my $reader = PDF::Tools::Reader.new;
 
    note "parsing {$input} ...";
    $reader.open( $input, :rebuild-index );

    note "writing {$output}...";
    my $pdf-writer = PDF::Tools::Writer.new( );
    $output.IO.spurt( $pdf-writer.write( :pdf($reader.ast), :root-obj( $reader.root-obj) ), :enc<latin1> );
}

