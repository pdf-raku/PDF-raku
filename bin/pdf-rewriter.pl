use v6;

# Simple round trip read and rewrite a PDF
use v6;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Core::Input;
use PDF::Core::Writer;

sub MAIN (Str $input-file, Str $output-file) {

    my $actions = PDF::Grammar::PDF::Actions.new;
    note "loading {$input-file}...";
    my $input = PDF::Core::Input.new-delegate: :value($input-file.IO.open( :r, :enc<latin1> ) );
 
    note "parsing...";
    PDF::Grammar::PDF.parse( ~$input, :$actions)
        or die "unable to load pdf: $input-file";

    my $pdf-ast = $/.ast;

    note "writing {$output-file}...";
    my $root-object = find-root( $pdf-ast, $input );
    my $pdf-writer = PDF::Core::Writer.new( :$input, :$root-object );
    $output-file.IO.spurt( $pdf-writer.write( :pdf($pdf-ast) ), :enc<latin1> );
}

#= temporary sub
sub find-root(Hash $ast, PDF::Core::Input $input) {

    use PDF::Core::IndObj;
    my %ind-obj-idx;
    my $root-obj;

    if $ast.defined {
        # pass 1: index top level objects
        for $ast<body>.list  {
            for .<objects>.list {
                next unless my $ind-obj = .<ind-obj>;
                my $obj-num = $ind-obj[0].Int;
                my $gen-num = $ind-obj[1].Int;
                %ind-obj-idx{$obj-num}{$gen-num} = $ind-obj;
            }
        }

        # pass 2: reconcile XRefs (Cross Rereference Streams), Handle ObjStm (Object Streams) 
        for %ind-obj-idx.values.sort.map: { .values.sort } -> $ind-obj {
            my $obj-num = $ind-obj[0].Int;
            my $gen-num = $ind-obj[1].Int;

            for $ind-obj[2] {
                my ($token-type, $val) = .kv;
                if $token-type eq 'stream' && $val<dict><Type>.defined {

                    given $val<dict><Type>.value {
                        when 'XRef' {
                            warn "obj $obj-num $gen-num: TBA cross reference streams (/Type /$_)";
                            # locate document root
                            $root-obj //= $val<dict><Root>;
                            my $xref-obj = PDF::Core::IndObj.new-delegate( :$ind-obj, :$input );
                            my $xref-data = $xref-obj.decode;
                            warn :$xref-data.perl;
                        }
                        when 'ObjStm' {
                            # these contain nested objects
                            warn "obj $obj-num $gen-num: TBA object streams (/Type /$_)";
                            my $objstm-obj = PDF::Core::IndObj.new-delegate( :$ind-obj, :$input );
                            my $objstm-data = $objstm-obj.decode;
                            warn :$objstm-data.perl;
                        }
                    }
                }
            }
        }
    }

    $root-obj;
}
