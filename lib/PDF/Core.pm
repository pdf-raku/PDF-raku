use v6;

class PDF::Core {

    use PDF::Core::Input;

    has PDF::Core::Input $.input is rw;  # raw PDF image (latin-1 encoding)
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
    multi method stream-data( Hash :$stream! ) {
        return $stream<encoded>
            if $stream<encoded>.defined;
        my $start = $stream<start>;
        my $end = $stream<end>;
        my $length = $end - $start + 1;
        $.input.substr($start - 1, $length - 1 );
    }
    multi method stream-data( *@args, *%opts ) is default {

        die "unexpected arguments: {[@args].perl}"
            if @args;
        
        die "unable to handle {%opts.keys} struct: {%opts.perl}"
    }

    method writer(:$offset) {
        require PDF::Core::Writer;
        ::('PDF::Core::Writer').new( :pdf(self), :$offset );
    }

    method write( :$offset = 0, *%opt ) {
        $.writer(:$offset).write( |%opt );
    }

    multi submethod BUILD(Hash :$ast, :$input) {

        $!input = PDF::Core::Input.new-delegate( :value($input) )
            if $input.defined;

        use PDF::Core::IndObj;

        if $ast.defined {
            # pass 1: index top level objects
            for $ast<body>.list  {
                for .<objects>.list {
                    next unless my $ind-obj = .<ind-obj>;
                    my $obj-num = $ind-obj[0].Int;
                    my $gen-num = $ind-obj[1].Int;
                    %!ind-obj-idx{$obj-num}{$gen-num} = $ind-obj;
                }
            }

            # pass 2: reconcile XRefs (Cross Rereference Streams), Handle ObjStm (Object Streams) 
            for %!ind-obj-idx.values.sort.map: { .values.sort } -> $ind-obj {
                my $obj-num = $ind-obj[0].Int;
                my $gen-num = $ind-obj[1].Int;

                for $ind-obj[2] {
                    my ($token-type, $val) = .kv;
                    if $token-type eq 'stream' && $val<dict><Type>.defined {

                        given $val<dict><Type>.value {
                            when 'XRef' {
                                warn "obj $obj-num $gen-num: TBA cross reference streams (/Type /$_)";
                                # locate document root
                                $!root-obj //= $val<dict><Root>;
                                my $xref-obj = PDF::Core::IndObj.new-delegate( :$ind-obj, :$!input );
                                my $xref-data = $xref-obj.decode;
                                warn :$xref-data.perl;
                            }
                            when 'ObjStm' {
                                # these contain nested objects
                                warn "obj $obj-num $gen-num: TBA object streams (/Type /$_)";
                                my $objstm-obj = PDF::Core::IndObj.new-delegate( :$ind-obj, :$!input );
                                my $objstm-data = $objstm-obj.decode;
                                warn :$objstm-data.perl;
                            }
                        }
                    }
                }
            }
        }
    }

}
