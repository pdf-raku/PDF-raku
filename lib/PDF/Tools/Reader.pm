use v6;

class PDF::Tools::Reader {

    use PDF::Grammar::PDF;
    use PDF::Grammar::PDF::Actions;

    has $.input is rw;  # raw PDF image (latin-1 encoding)
    has Int $.xref-offset is rw;
    has Hash @.ind-obj-idx;
    has $.root-obj is rw;
    has $.ast is rw;
    has Rat $.version is rw;
    has Bool $.debug is rw;

    multi method open( Str $input, *%opts) {
        $.open( $input.IO.open( :enc<latin-1> ), |%opts );
    }

    multi method open( $input!, Bool :$rebuild-index? ) {
        use PDF::Tools::Input;

        $!input = $input.isa(PDF::Tools::Input)
                  ?? $input
                  !! PDF::Tools::Input.new-delegate( :value($input) );

        warn $!input.perl;

        my $actions = PDF::Grammar::PDF::Actions.new;

        $.load-header( :$actions );
        $.load-trailer( :$actions );

    }

    method load-header(:$actions!) {
        # file should start with: %PDF-n.m, (where n, m are single
        # digits giving the major and minor version numbers).
            
        my $preamble = $.input.substr(0, 8);

        PDF::Grammar::PDF.parse($preamble, :$actions, :rule<header>)
            or die "expected file header '%PDF-n.m', got: {$preamble.perl}";

        $.version = $/.ast.value;
        warn "pdf version is: {$.version}"
            if $.debug || True;
    }

    method load-trailer(:$actions) {
        # locate and read the file trailer
        # hmm, arbritary magic number
        my $tail-bytes = min(1024, $.input.chars);
        my $tail = $.input.substr(* - $tail-bytes);
        warn "bytes: { $tail-bytes }   tail: {$tail.perl}"
            if $.debug || True;

        PDF::Grammar::PDF.parse($tail, :$actions, :rule<postamble>)
            or die "expected file trailer 'startxref ... \%\%EOF', got: {$tail.perl}";
        $.xref-offset = $/.ast.value;

        # see if our cross reference table is already contained in the current tail
        my $xref;
        my $tail-xref-pos = $!xref-offset - $.input.chars + $tail-bytes + 1;
        if $tail-xref-pos >= 0 {
            $xref = $tail.substr( $tail-xref-pos );
        }
        else {
            die "todo: extract trailer from offset: $!xref-offset";
        }

        if $xref ~~ /^'xref'/ {
            # PDF 1.4- xref table followed by trailer
            PDF::Grammar::PDF.subparse( $xref, :rule<index>, :$actions )
                or die "unable to parse index: $xref";
            my ($xref-ast, $trailer-ast) = @( $/.ast );

            for $xref-ast<xref>.list {
                for @( .<entries> ) {
                    my $status = .<status>;
                    my $gen = .<gen>;
                    my $offset = .<offset>;
                    next if $status eq 'f'; # don't index free objects

                    @.ind-obj-idx.push: { :$gen, :$offset };
                }
            }

            $.root-obj //= $trailer-ast<trailer>.value<Root>
                or die "root object not found in trailer dictionary";
        }
        else {
            die "tba: xref grok PDF 1.5+ $xref";
        }

    }

}
