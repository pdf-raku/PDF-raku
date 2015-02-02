use v6;

class PDF::Core {

    has $.input is rw;  # raw PDF image (latin-1 encoding)
    has Int $.xref-offset is rw;
    has Hash %.ind-obj-idx;
    has $.root-obj is rw;
    has Rat $.version is rw;
    has Bool $.debug is rw;

    multi method open(Str $fname) {
        my $ioh = $fname.IO.open( :r, :enc<latin1> );
        $.open( $ioh );
    }

    multi method open( IO::Handle $ioh ) {
        use PDF::Grammar::PDF;
        use PDF::Grammar::PDF::Actions;
        use PDF::Core::Input;

        $.input = PDF::Core::Input.new-delegate( :value($ioh) );

        my $actions = PDF::Grammar::PDF::Actions.new;

        {
            # file should start with: %PDF-n.m, (where n, m are single
            # digits giving the major and minor version numbers).
            
            my $preamble = $.input.substr(0, 8);
            warn :$preamble.perl;

            PDF::Grammar::PDF.parse($preamble, :$actions, :rule<header>)
                or die "expected file header '%PDF-n.m', got: {$preamble.perl}";

            $.version = $/.ast.value;
            warn "pdf version is: {$.version}"
                if $.debug || True;
        }

        {
            # now locate and read the file trailer
            # hmm, arbritary random number
            my $postamble = $.input.substr(* - 512);
            warn "postamble: {$postamble.perl}"
                if $.debug || True;

            PDF::Grammar::PDF.parse($postamble, :$actions, :rule<postamble>)
                or die "expected file trailer 'startxref ... \%\%EOF', got: {$postamble.perl}";
            $.xref-offset = $/.ast.value;
        }

        warn "under construction...";
        # stub
        self;
    }

    #| retrieves raw stream data from the input object
    multi method stream-data( Array :$ind-obj! ) {
        return
            unless $ind-obj[2].key eq 'stream';
        $.stream-data( |%( $ind-obj[2] ) );
    }

    method writer(:$offset) {
        require PDF::Core::Writer;
        ::('PDF::Core::Writer').new( :pdf(self), :$offset );
    }

    method write( :$offset = 0, *%opt ) {
        $.writer(:$offset).write( |%opt );
    }


}
