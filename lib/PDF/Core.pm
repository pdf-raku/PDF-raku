use v6;

class PDF::Core {

    has Str $.input;  # raw PDF image (latin-1 encoding)
    has Hash %.ind-obj-idx;
    has $.root-obj is rw;

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

    multi submethod BUILD(Hash :$ast, Str :$!input) {

        use PDF::Core::IndObj;

        if $ast.defined {
            # pass 1: index top level objects
            for $ast<body>.list  {
                for .<objects>.list {
                    next unless my $ind-obj = .<ind-obj>;
               warn :$ind-obj.perl;
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
