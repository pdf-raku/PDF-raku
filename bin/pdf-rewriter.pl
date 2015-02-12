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
    my $ast = $reader.ast;

    note "writing {$output-path}...";
    my $root-object = :ind-ref[ $reader.root-obj.obj-num, $reader.root-obj.gen-num];
    my $pdf-writer = PDF::Tools::Writer.new( :$root-object );
    $output-path.IO.spurt( $pdf-writer.write( $ast ), :enc<latin1> );
}

