use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Basic;

sub MAIN ($input-file, $output-file) {

    my $actions = PDF::Grammar::PDF::Actions.new;
    note "loading {$input-file}...";
    my $pdf-content = $input-file.IO.slurp( :enc<latin1> );
 
    note "parsing...";
    PDF::Grammar::PDF.parse($pdf-content, :$actions)
        or die "unable to load pdf: $input-file";

    my $pdf-ast = $/.ast;

    note "writing {$output-file}...";
    my $pdf = PDF::Basic.new( :ast($pdf-ast), :input($pdf-content) );
    $output-file.IO.spurt( $pdf.write( :pdf($pdf-ast) ), :enc<latin1> );
}
